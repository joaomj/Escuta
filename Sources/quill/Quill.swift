import AppKit
import ArgumentParser
import EscutaCore
import Foundation

@main
struct Quill: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "quill",
        abstract: "Local meeting recorder + transcriber. Records mic and system audio as two tracks, then transcribes on-device.",
        subcommands: [Run.self, Record.self, Doctor.self, DownloadModel.self, Install.self],
        defaultSubcommand: Run.self
    )
}

struct Record: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Record in the terminal until Ctrl-C, then transcribe."
    )

    @Option(name: .long, help: "Recordings root directory (overrides the config file).")
    var out: String?

    mutating func run() async throws {
        try await runMain()
    }

    @MainActor
    private func runMain() async throws {
        let root = Config.resolveRoot(cliOverride: out)
        let checks = DoctorReport.run(recordingsRoot: root)
        if !DoctorReport.recordingRootOK(checks) {
            DoctorReport.print(checks)
            throw ExitCode(1)
        }
        guard Config.whisperModelIsLocal() else {
            FileHandle.standardError.write(Data(
                "Whisper model is not downloaded. Run: quill download-model\n".utf8
            ))
            throw ExitCode(1)
        }

        let session = try RecordingSession(root: root)
        do {
            try session.start()
        } catch {
            FileHandle.standardError.write(Data("recording start failed: \(error)\n".utf8))
            throw ExitCode(1)
        }

        print("recording → \(session.dir.path)")
        print("press Ctrl-C to stop")
        let ticker = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                print("recording · \(Self.format(Date().timeIntervalSince(session.startedAt)) )")
            }
        }

        await Self.waitForInterrupt()
        ticker.cancel()

        do {
            try session.stop()
        } catch {
            FileHandle.standardError.write(Data("recording finalization failed: \(error)\n".utf8))
            throw ExitCode(1)
        }
        print("stopped · \(session.dir.path)")

        let transcription = TranscriptionCoordinator()
        await transcription.setStatusHandler { status in
            Self.printStatus(status)
        }
        switch await transcription.transcribeAndWait(session.dir) {
        case .completed(let transcript):
            print("transcript ready · \(transcript.path)")
        case .failed(let log):
            FileHandle.standardError.write(Data("transcription failed · \(log.path)\n".utf8))
            throw ExitCode(1)
        case .disabled:
            print("transcription disabled · \(session.dir.path)")
        }
    }

    private static func waitForInterrupt() async {
        await withCheckedContinuation { continuation in
            let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            source.setEventHandler {
                source.cancel()
                signal(SIGINT, SIG_DFL)
                continuation.resume()
            }
            signal(SIGINT, SIG_IGN)
            source.resume()
        }
    }

    private static func printStatus(_ status: TranscriptionCoordinator.Status) {
        switch status {
        case .idle:
            break
        case .waitingForModel(let model, let queued):
            print("waiting for model \(model) · \(queued) queued")
        case .downloadingModel(let model, let fraction):
            print("downloading \(model) · \(Int(fraction * 100))%")
        case .loadingModel(let model):
            print("loading \(model)")
        case .transcribing(let session, let track, let progress, _):
            let detail = progress.map { " · \($0)" } ?? ""
            print("transcribing \(session) · \(track)\(detail)")
        case .ready, .failed:
            break
        }
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

struct DownloadModel: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "download-model",
        abstract: "Download the configured WhisperKit model and tokenizer."
    )

    mutating func run() async throws {
        if Config.whisperModelIsLocal() {
            print("model already available: \(Config.whisperModelDestination().path)")
            return
        }

        print("downloading \(Config.whisperModel()) (\(Config.whisperModelApproximateSize()))")
        print("destination: \(Config.whisperModelDestination().path)")
        do {
            try await WhisperKitEngine.download { fraction in
                let percent = Int(fraction * 100)
                FileHandle.standardError.write(Data("\rdownload progress: \(percent)%".utf8))
            }
            FileHandle.standardError.write(Data("\n".utf8))
            print("model download complete")
        } catch {
            FileHandle.standardError.write(Data("\nmodel download failed: \(error)\n".utf8))
            throw ExitCode(1)
        }
    }
}

struct Run: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run the menu-bar daemon (default)."
    )

    @Option(name: .long, help: "Recordings root directory (overrides the config file).")
    var out: String?

    mutating func run() async throws {
        try await MainActor.run { try runMain() }
    }

    @MainActor
    private func runMain() throws {
        let root = Config.resolveRoot(cliOverride: out)

        // Non-blocking: permissions prompt on first recording, so warnings at
        // startup are informational, not fatal.
        let checks = DoctorReport.run(recordingsRoot: root)
        if !DoctorReport.recordingRootOK(checks) {
            FileHandle.standardError.write(Data("startup checks failed:\n".utf8))
            DoctorReport.print(checks)
            throw ExitCode(1)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let controller = AppController(root: root)

        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigint.setEventHandler {
            FileHandle.standardError.write(Data("\nshutting down\n".utf8))
            MainActor.assumeIsolated { controller.shutdown() }
        }
        sigint.resume()
        signal(SIGINT, SIG_IGN)

        FileHandle.standardError.write(Data(
            "quill up · recordings → \(root.path) · ^C to quit\n".utf8
        ))
        notifyUser(title: "Escuta is running", body: "Look for Escuta in the menu bar")
        app.run()
    }
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check microphone, system audio, and recordings folder."
    )

    func run() throws {
        let checks = DoctorReport.run(recordingsRoot: Config.resolveRoot(cliOverride: nil))
        DoctorReport.print(checks)
        if !DoctorReport.allOK(checks) {
            throw ExitCode(1)
        }
    }
}

/// Owns the menu bar, the current recording session, and the elapsed-time
/// ticker. All state transitions happen on the main actor.
@MainActor
final class AppController {
    private let root: URL
    private let menuBar = MenuBarController(language: Config.languagePreference())
    private let transcription = TranscriptionCoordinator()
    private var session: RecordingSession?
    private var ticker: Timer?
    private var latestTranscript: URL?
    private var failedSession: URL?

    init(root: URL) {
        self.root = root
        menuBar.onToggle = { [weak self] in self?.toggle() }
        menuBar.onOpenFolder = { [weak self] in self?.openFolder() }
        menuBar.onQuit = { [weak self] in self?.shutdown() }
        menuBar.onLanguagePreference = { [weak self] preference in
            self?.setLanguagePreference(preference)
        }
        menuBar.onDownloadModel = { [weak self] in self?.confirmModelDownload() }
        menuBar.onOpenLatestTranscript = { [weak self] in self?.openLatestTranscript() }
        menuBar.onRetryFailed = { [weak self] in self?.retryFailed() }
        menuBar.onOpenMicrophoneSettings = { Self.openMicrophoneSettings() }
        menuBar.update(recording: false, elapsed: nil)
        menuBar.updateModel(
            local: Config.whisperModelIsLocal(),
            model: Config.whisperModel(),
            size: Config.whisperModelApproximateSize(),
            destination: Config.whisperModelDestination().path
        )
        menuBar.updateSetup(Self.setupText())
        menuBar.updateMicrophonePermission(DoctorReport.microphonePermission())
        let latest = Self.latestSessionState(in: root)
        latestTranscript = latest.transcript
        failedSession = latest.failed
        menuBar.updateLatestTranscript(available: latest.transcript != nil)
        menuBar.updateRetry(available: latest.failed != nil)

        Task { [transcription, root] in
            await transcription.setStatusHandler { status in
                Task { @MainActor [weak self] in
                    self?.showTranscription(status)
                }
            }
            await transcription.resumePending(root: root)
        }
    }

    /// Stop any live session cleanly (finalizing files) and exit.
    func shutdown() {
        stopSession()
        NSApp.terminate(nil)
    }

    private func toggle() {
        if session == nil {
            startSession()
        } else {
            stopSession()
        }
    }

    private func startSession() {
        do {
            let newSession = try RecordingSession(root: root)
            try newSession.start()
            session = newSession
            FileHandle.standardError.write(Data("● recording → \(newSession.dir.path)\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("recording start failed: \(error)\n".utf8))
            notifyUser(title: "quill — recording failed", body: "\(error)")
            return
        }

        menuBar.update(recording: true, elapsed: "0:00")
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stopSession() {
        guard let session else { return }
        do {
            try session.stop()
        } catch {
            FileHandle.standardError.write(Data(
                "recording finalization failed: \(error)\n".utf8
            ))
            notifyUser(
                title: "quill — recording finalization failed",
                body: "Audio remains in \(session.dir.path)"
            )
        }
        let elapsed = Self.format(Date().timeIntervalSince(session.startedAt))
        FileHandle.standardError.write(Data(
            "○ stopped · \(elapsed) · \(session.dir.path)\n".utf8
        ))
        self.session = nil
        ticker?.invalidate()
        ticker = nil
        menuBar.update(recording: false, elapsed: nil)

        let dir = session.dir
        Task { [transcription] in await transcription.enqueue(dir) }
    }

    private func showTranscription(_ status: TranscriptionCoordinator.Status) {
        switch status {
        case .idle:
            menuBar.updateTranscription(nil)
            menuBar.updateRetry(available: failedSession != nil)
            menuBar.updateModel(
                local: Config.whisperModelIsLocal(),
                model: Config.whisperModel(),
                size: Config.whisperModelApproximateSize(),
                destination: Config.whisperModelDestination().path
            )
        case .waitingForModel(let model, let queued):
            menuBar.updateTranscription(
                "model \(model) not downloaded · \(queued) queued"
            )
        case .downloadingModel(let model, let fraction):
            menuBar.updateTranscription(
                "downloading \(model) · \(Int(fraction * 100))%"
            )
        case .loadingModel(let model):
            menuBar.updateTranscription("loading \(model)")
        case .transcribing(let name, let track, let progress, let queued):
            let queueText = queued > 0 ? " · \(queued) queued" : ""
            let progressText = progress.map { " · \($0)" } ?? ""
            menuBar.updateTranscription(
                "transcribing \(name) · \(track)\(progressText)\(queueText)"
            )
        case .ready(let name, let transcript):
            latestTranscript = transcript
            failedSession = nil
            menuBar.updateTranscription("transcript ready · \(name)")
            menuBar.updateLatestTranscript(available: true)
            menuBar.updateRetry(available: false)
        case .failed(let name, _, let directory):
            failedSession = directory
            menuBar.updateTranscription("transcription failed · \(name) · see log")
            menuBar.updateRetry(available: true)
        }
    }

    private func tick() {
        guard let session else { return }
        menuBar.update(
            recording: true,
            elapsed: Self.format(Date().timeIntervalSince(session.startedAt))
        )
    }

    private func openFolder() {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(root)
    }

    private func setLanguagePreference(_ preference: LanguagePreference) {
        do {
            try Config.setLanguagePreference(preference)
            menuBar.updateLanguage(preference)
        } catch {
            notifyUser(title: "quill — language was not saved", body: "\(error)")
        }
    }

    private func confirmModelDownload() {
        guard !Config.whisperModelIsLocal() else { return }
        let alert = NSAlert()
        alert.messageText = "Download the Whisper model?"
        alert.informativeText = "\(Config.whisperModel()) (\(Config.whisperModelApproximateSize())) will be saved to \(Config.whisperModelDestination().path). The download needs an internet connection."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Not now")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { [transcription] in await transcription.downloadModel() }
    }

    private func openLatestTranscript() {
        guard let latestTranscript else { return }
        NSWorkspace.shared.open(latestTranscript)
    }

    private func retryFailed() {
        guard let failedSession else { return }
        Task { [transcription] in await transcription.retryFailed(failedSession) }
    }

    private static func setupText() -> String {
        let microphone: String
        switch DoctorReport.microphonePermission() {
        case .allowed:
            microphone = "microphone allowed"
        case .notRequested:
            microphone = "microphone not requested"
        case .denied:
            microphone = "microphone denied · enable in System Settings"
        }
        return "\(microphone) · system audio asks on first recording"
    }

    private static func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func latestSessionState(in root: URL) -> (transcript: URL?, failed: URL?) {
        guard let directories = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return (nil, nil) }

        let sessions = directories.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.sorted { $0.lastPathComponent > $1.lastPathComponent }

        var transcript: URL?
        var failed: URL?
        for directory in sessions {
            guard let metadata = try? SessionMetadata.read(from: directory) else { continue }
            if metadata.state == .completed, transcript == nil {
                transcript = directory.appendingPathComponent("transcript.md")
            }
            if metadata.state == .failed, failed == nil {
                failed = directory
            }
            if transcript != nil, failed != nil { break }
        }
        return (transcript, failed)
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
