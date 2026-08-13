import Foundation
import EscutaCore

func runTranscriptTests() throws {
    try testMergesTrackSegmentsBySharedTimestamp()
    try testWritesTranscriptJSONAndReadableMarkdown()
}

private func testMergesTrackSegmentsBySharedTimestamp() throws {
    let tracks = [
        TranscriptTrack(
            speaker: "me",
            offsetMs: 250,
            segments: [
                RelativeTranscriptSegment(start: 2, end: 3, text: "later")
            ]
        ),
        TranscriptTrack(
            speaker: "them",
            offsetMs: 0,
            segments: [
                RelativeTranscriptSegment(start: 1, end: 2, text: "first")
            ]
        ),
    ]

    let result = TranscriptMerger.merge(tracks)

    try expect(result.map(\.speaker) == ["them", "me"], "speaker order")
    try expect(result.map(\.startMs) == [1000, 2250], "start offsets")
    try expect(result.map(\.endMs) == [2000, 3250], "end offsets")
}

private func testWritesTranscriptJSONAndReadableMarkdown() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let document = TranscriptDocument(
        engine: "test-engine",
        model: "test-model",
        createdAt: "2026-08-12T00:00:00Z",
        segments: [
            TranscriptSegment(
                speaker: "me",
                startMs: 3_661_000,
                endMs: 3_662_000,
                text: "A long meeting point"
            )
        ],
        warnings: ["system track unavailable"]
    )

    try document.write(to: directory)

    let json = try JSONSerialization.jsonObject(
        with: Data(contentsOf: directory.appendingPathComponent("transcript.json"))
    ) as? [String: Any]
    let markdown = try String(
        contentsOf: directory.appendingPathComponent("transcript.md"),
        encoding: .utf8
    )

    try expect(json?["schema_version"] as? Int == 1, "transcript schema")
    try expect(json?["engine"] as? String == "test-engine", "engine metadata")
    try expect(markdown.contains("[1:01:01] me:"), "long timestamp")
    try expect(
        markdown.contains("warning: system track unavailable"),
        "transcript warning"
    )
}

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("escuta-core-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
