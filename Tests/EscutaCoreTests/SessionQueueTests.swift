import Foundation
import EscutaCore

func runSessionQueueTests() throws {
    try testRecoversRecordingSessions()
    try testReturnsPendingSessionsInFolderOrder()
    try testCheckpointMatchesTrackAndEngineIdentity()
}

private func testRecoversRecordingSessions() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let session = root.appendingPathComponent("2026.08.12-0900", isDirectory: true)
    try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
    try SessionMetadata(
        state: .recording,
        started: "2026-08-12T09:00:00Z",
        files: ["mic": "mic.caf", "system": "system.caf"]
    ).write(to: session)

    let recovered = try SessionQueue.recoverInterruptedSessions(
        in: root,
        now: "2026-08-12T09:30:00Z"
    )
    let metadata = try SessionMetadata.read(from: session)

    try expect(
        recovered.map(\.standardizedFileURL.path) == [session.standardizedFileURL.path],
        "recovered session: \(recovered.map(\.lastPathComponent)), state=\(metadata.state)"
    )
    try expect(metadata.state == .pending, "recovered state")
    try expect(metadata.ended == "2026-08-12T09:30:00Z", "recovered end time")
    try expect(
        metadata.warnings.contains("recording was interrupted; available tracks will be transcribed"),
        "recovery warning"
    )
}

private func testReturnsPendingSessionsInFolderOrder() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    for name in ["2026.08.12-1000", "2026.08.12-0900", "2026.08.12-1100"] {
        let session = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        try SessionMetadata(
            state: name.hasSuffix("1100") ? .failed : .pending,
            started: name,
            files: ["mic": "mic.caf"]
        ).write(to: session)
    }

    let pending = try SessionQueue.pendingSessions(in: root)

    try expect(
        pending.map(\.lastPathComponent) == ["2026.08.12-0900", "2026.08.12-1000"],
        "oldest pending order"
    )
}

private func testCheckpointMatchesTrackAndEngineIdentity() throws {
    let track = SessionTrack(
        name: "mic",
        file: "mic.caf",
        speaker: "me",
        offsetMs: 12
    )
    let checkpoint = TrackTranscriptCheckpoint(
        track: "mic",
        file: "mic.caf",
        speaker: "me",
        offsetMs: 12,
        engine: "test-engine",
        engineVersion: "test-version",
        model: "test-model",
        createdAt: "2026-08-12T00:00:00Z",
        segments: [RelativeTranscriptSegment(start: 0, end: 1, text: "hello")]
    )

    try expect(
        checkpoint.matches(
            track,
            engine: "test-engine",
            engineVersion: "test-version",
            model: "test-model"
        ),
        "matching checkpoint"
    )
    try expect(
        !checkpoint.matches(
            track,
            engine: "other-engine",
            engineVersion: "test-version",
            model: "test-model"
        ),
        "engine checkpoint mismatch"
    )
    try expect(
        !checkpoint.matches(
            track,
            engine: "test-engine",
            engineVersion: "test-version",
            model: "other-model"
        ),
        "model checkpoint mismatch"
    )
}

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("escuta-core-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
