import Foundation
import EscutaCore

func runSessionMetadataTests() throws {
    try testWritesAndReadsTypedMetadata()
    try testReadsMetadataWrittenBeforeTheSchemaVersion()
}

private func testWritesAndReadsTypedMetadata() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let metadata = SessionMetadata(
        state: .pending,
        started: "2026-08-12T00:00:00Z",
        ended: "2026-08-12T00:30:00Z",
        durationSeconds: 1800,
        files: ["mic": "mic.caf", "system": "system.caf"],
        startOffsetMs: ["mic": 10, "system": 0]
    )

    try metadata.write(to: directory)
    let loaded = try SessionMetadata.read(from: directory)

    try expect(loaded == metadata, "metadata round trip")
    try expect(loaded.tracks == [
        SessionTrack(name: "mic", file: "mic.caf", speaker: "me", offsetMs: 10),
        SessionTrack(name: "system", file: "system.caf", speaker: "them", offsetMs: 0),
    ], "track mapping")
}

private func testReadsMetadataWrittenBeforeTheSchemaVersion() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let legacy: [String: Any] = [
        "started": "2026-08-12T00:00:00Z",
        "ended": "2026-08-12T00:30:00Z",
        "duration_seconds": 1800,
        "files": ["mic": "mic.caf", "system": "system.caf"],
        "start_offset_ms": ["mic": 10, "system": 0],
    ]
    let data = try JSONSerialization.data(withJSONObject: legacy)
    try data.write(to: directory.appendingPathComponent("meta.json"))

    let loaded = try SessionMetadata.read(from: directory)

    try expect(
        loaded.schemaVersion == SessionMetadata.currentSchemaVersion,
        "legacy schema version"
    )
    try expect(loaded.state == .pending, "legacy state")
    try expect(loaded.warnings.isEmpty, "legacy warnings")
}

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("escuta-core-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
