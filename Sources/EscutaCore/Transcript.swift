import Foundation

public struct RelativeTranscriptSegment: Codable, Equatable, Sendable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let text: String

    public init(start: TimeInterval, end: TimeInterval, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}

public struct TranscriptTrack: Sendable {
    public let speaker: String
    public let offsetMs: Int
    public let segments: [RelativeTranscriptSegment]

    public init(
        speaker: String,
        offsetMs: Int,
        segments: [RelativeTranscriptSegment]
    ) {
        self.speaker = speaker
        self.offsetMs = offsetMs
        self.segments = segments
    }
}

public struct TranscriptSegment: Codable, Equatable, Sendable {
    public let speaker: String
    public let startMs: Int
    public let endMs: Int
    public let text: String

    public init(speaker: String, startMs: Int, endMs: Int, text: String) {
        self.speaker = speaker
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case speaker
        case startMs = "start_ms"
        case endMs = "end_ms"
        case text
    }
}

public enum TranscriptMerger {
    public static func merge(_ tracks: [TranscriptTrack]) -> [TranscriptSegment] {
        tracks
            .flatMap { track in
                track.segments.map { segment in
                    TranscriptSegment(
                        speaker: track.speaker,
                        startMs: Int(segment.start * 1000) + track.offsetMs,
                        endMs: Int(segment.end * 1000) + track.offsetMs,
                        text: segment.text
                    )
                }
            }
            .sorted {
                if $0.startMs != $1.startMs {
                    return $0.startMs < $1.startMs
                }
                return $0.endMs < $1.endMs
            }
    }
}

public struct TranscriptDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let engine: String
    public let engineVersion: String
    public let model: String
    public let createdAt: String
    public let tracks: [TranscriptTrackInfo]
    public let segments: [TranscriptSegment]
    public let warnings: [String]

    public init(
        engine: String,
        engineVersion: String,
        model: String,
        createdAt: String,
        tracks: [TranscriptTrackInfo] = [],
        segments: [TranscriptSegment],
        warnings: [String] = [],
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.engine = engine
        self.engineVersion = engineVersion
        self.model = model
        self.createdAt = createdAt
        self.tracks = tracks
        self.segments = segments
        self.warnings = warnings
    }

    public func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self)
            .write(
                to: directory.appendingPathComponent("transcript.json"),
                options: .atomic
            )
        try Data(markdown(title: directory.lastPathComponent).utf8)
            .write(
                to: directory.appendingPathComponent("transcript.md"),
                options: .atomic
            )
    }

    public func markdown(title: String) -> String {
        var lines = [
            "# \(title)",
            "",
            "engine: \(engine) \(engineVersion) (\(model))",
            "",
        ]
        if !warnings.isEmpty {
            lines.append("warning: \(warnings.joined(separator: "; "))")
            lines.append("")
        }
        for segment in segments {
            lines.append(
                "**[\(Self.clock(segment.startMs))] \(segment.speaker):** \(segment.text)"
            )
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case engine
        case engineVersion = "engine_version"
        case model
        case createdAt = "created_at"
        case tracks
        case segments
        case warnings
    }

    private static func clock(_ milliseconds: Int) -> String {
        let total = milliseconds / 1000
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
