import AVFoundation
import Foundation
import EscutaCore

/// Post-recording pipeline: a serial queue of session folders to transcribe.
/// mic.caf → "me", system.caf → "them"; each track's segments are shifted by
/// its start offset, merged by timestamp, and written as transcript.json
/// (canonical) plus transcript.md (readable). The filesystem is the queue —
/// `resumePending()` rescans at launch, so a crash or quit mid-transcription
/// just retries on next run. Failures append to the session's transcribe.log
/// and never block later jobs.
actor TranscriptionCoordinator {
    enum Status: Sendable {
        case idle
        case transcribing(session: String, queued: Int)
        case failed(session: String)
    }

    private var queue: [URL] = []
    private var activeSession: URL?
    private var draining = false
    private var engine: TranscriptionEngine?
    private var lastFailure: String?
    private var statusHandler: (@Sendable (Status) -> Void)?

    func setStatusHandler(_ handler: @escaping @Sendable (Status) -> Void) {
        statusHandler = handler
    }

    /// Queue a finished session. With transcription disabled in config, the
    /// on_stop hook still fires — it just gets an untranscribed folder.
    func enqueue(_ sessionDir: URL) {
        guard Config.transcriptionEnabled() else {
            runHook(for: sessionDir)
            return
        }
        appendIfNeeded(sessionDir)
        drainIfIdle()
    }

    /// Recover recording sessions and scan the filesystem queue.
    func resumePending(root: URL) {
        guard Config.transcriptionEnabled() else { return }
        do {
            let recovered = try SessionQueue.recoverInterruptedSessions(
                in: root,
                now: ISO8601DateFormatter().string(from: Date())
            )
            let pending = try SessionQueue.pendingSessions(in: root)
            for dir in pending {
                appendIfNeeded(dir)
            }
            if !recovered.isEmpty {
                FileHandle.standardError.write(Data(
                    "recovered \(recovered.count) interrupted session(s)\n".utf8
                ))
            }
            if !pending.isEmpty {
                FileHandle.standardError.write(Data(
                    "resuming \(pending.count) queued session(s)\n".utf8
                ))
            }
        } catch {
            FileHandle.standardError.write(Data(
                "queue scan failed for \(root.path): \(error)\n".utf8
            ))
        }
        drainIfIdle()
    }

    func retryFailed(_ sessionDir: URL) {
        do {
            var metadata = try SessionMetadata.read(from: sessionDir)
            guard metadata.state == .failed else { return }
            metadata.state = .pending
            metadata.warnings.removeAll()
            try metadata.write(to: sessionDir)
            appendIfNeeded(sessionDir)
            drainIfIdle()
        } catch {
            log(sessionDir, "retry request failed: \(error)")
        }
    }

    // MARK: -

    private func drainIfIdle() {
        guard !draining, !queue.isEmpty else { return }
        draining = true
        lastFailure = nil
        Task { await drain() }
    }

    private func drain() async {
        while !queue.isEmpty {
            let dir = queue.removeFirst()
            activeSession = dir
            publish(.transcribing(session: dir.lastPathComponent, queued: queue.count))
            do {
                try await transcribe(dir)
                notifyUser(title: "quill — transcript ready", body: dir.lastPathComponent)
                runHook(for: dir)
            } catch {
                markFailed(dir, error: error)
                log(dir, "transcription failed: \(error)")
                lastFailure = dir.lastPathComponent
                notifyUser(
                    title: "quill — transcription failed",
                    body: "\(dir.lastPathComponent) — see transcribe.log"
                )
            }
        }
        activeSession = nil
        await engine?.release()
        engine = nil
        publish(lastFailure.map { .failed(session: $0) } ?? .idle)
        draining = false
        // An enqueue that landed between the loop exiting and the release
        // finishing would otherwise sit until the next enqueue.
        drainIfIdle()
    }

    private func transcribe(_ dir: URL) async throws {
        var meta = try SessionMetadata.read(from: dir)
        guard meta.state != .completed else { return }
        meta.state = .transcribing
        try meta.write(to: dir)

        let engine = try await preparedEngine()

        var tracks: [TranscriptTrack] = []
        var warnings = meta.warnings
        for track in meta.tracks {
            let audio = dir.appendingPathComponent(track.file)
            if let checkpoint = try? TrackTranscriptCheckpoint.read(
                track: track.name,
                from: dir.appendingPathComponent("checkpoints", isDirectory: true)
            ), checkpoint.matches(track, engine: engine.name, model: engine.model) {
                tracks.append(TranscriptTrack(
                    speaker: checkpoint.speaker,
                    offsetMs: checkpoint.offsetMs,
                    segments: checkpoint.segments
                ))
                log(dir, "resumed \(track.file) from checkpoint")
                continue
            }

            guard readableAudio(at: audio) else {
                let warning = "\(track.name) track unavailable: \(track.file)"
                if !warnings.contains(warning) { warnings.append(warning) }
                log(dir, "skipping unreadable track \(track.file)")
                continue
            }
            log(dir, "transcribing \(track.file) (\(engine.name))")
            let segments: [RelativeTranscriptSegment]
            do {
                segments = try await engine.transcribe(audio)
            } catch {
                let warning = "\(track.name) track transcription failed"
                if !warnings.contains(warning) { warnings.append(warning) }
                log(dir, "skipping \(track.file): \(error)")
                continue
            }
            try TrackTranscriptCheckpoint(
                track: track.name,
                file: track.file,
                speaker: track.speaker,
                offsetMs: track.offsetMs,
                engine: engine.name,
                model: engine.model,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                segments: segments
            ).write(to: dir.appendingPathComponent("checkpoints", isDirectory: true))
            tracks.append(TranscriptTrack(
                speaker: track.speaker,
                offsetMs: track.offsetMs,
                segments: segments
            ))
        }
        guard !tracks.isEmpty else {
            throw TranscriptionError.noReadableTracks
        }
        let merged = TranscriptMerger.merge(tracks)

        let transcript = TranscriptDocument(
            engine: engine.name,
            model: engine.model,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            segments: merged,
            warnings: warnings
        )
        try transcript.write(to: dir)
        meta.state = .completed
        meta.ended = meta.ended ?? ISO8601DateFormatter().string(from: Date())
        meta.warnings = warnings
        try meta.write(to: dir)
        log(dir, "done — \(merged.count) segments")
    }

    private func preparedEngine() async throws -> TranscriptionEngine {
        if let engine { return engine }
        let configured = Config.transcriptionEngine()
        if configured != "parakeet" {
            FileHandle.standardError.write(Data(
                "warning: unknown transcription engine \"\(configured)\" — using parakeet\n".utf8
            ))
        }
        let engine = ParakeetEngine()
        try await engine.prepare()
        self.engine = engine
        return engine
    }

    private func appendIfNeeded(_ sessionDir: URL) {
        let normalized = sessionDir.standardizedFileURL
        guard normalized != activeSession?.standardizedFileURL,
              !queue.contains(where: { $0.standardizedFileURL == normalized })
        else { return }
        queue.append(normalized)
    }

    private func readableAudio(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let audio = try? AVAudioFile(forReading: url) else { return false }
        return audio.length > 0
    }

    private func markFailed(_ dir: URL, error: Error) {
        guard var metadata = try? SessionMetadata.read(from: dir) else { return }
        metadata.state = .failed
        let warning = "transcription failed: \(error)"
        if !metadata.warnings.contains(warning) { metadata.warnings.append(warning) }
        try? metadata.write(to: dir)
    }

    private enum TranscriptionError: Error, CustomStringConvertible {
        case noReadableTracks

        var description: String {
            switch self {
            case .noReadableTracks: return "no readable audio tracks"
            }
        }
    }

    /// Fires the configured on_stop shell command with the session directory
    /// as its sole argument, after the transcript exists (or immediately after
    /// recording when transcription is disabled).
    private func runHook(for dir: URL) {
        guard let cmd = Config.onStop() else { return }
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "\(cmd) \"$0\"", dir.path]
        do {
            try task.run()
        } catch {
            log(dir, "on_stop hook failed to launch: \(error)")
        }
    }

    private func log(_ dir: URL, _ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let url = dir.appendingPathComponent("transcribe.log")
        if let handle = FileHandle(forWritingAtPath: url.path) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }

    private func publish(_ status: Status) {
        statusHandler?(status)
    }
}
