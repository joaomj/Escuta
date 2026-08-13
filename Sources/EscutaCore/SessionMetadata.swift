import Foundation

public enum SessionState: String, Codable, Sendable {
    case recording
    case pending
    case transcribing
    case completed
    case failed
}

public struct SessionTrack: Codable, Equatable, Sendable {
    public let name: String
    public let file: String
    public let speaker: String
    public let offsetMs: Int

    public init(name: String, file: String, speaker: String, offsetMs: Int) {
        self.name = name
        self.file = file
        self.speaker = speaker
        self.offsetMs = offsetMs
    }
}

public struct SessionMetadata: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var state: SessionState
    public let started: String
    public var ended: String?
    public var durationSeconds: Int?
    public let files: [String: String]
    public var startOffsetMs: [String: Int]
    public var warnings: [String]

    public init(
        state: SessionState,
        started: String,
        ended: String? = nil,
        durationSeconds: Int? = nil,
        files: [String: String],
        startOffsetMs: [String: Int] = [:],
        warnings: [String] = [],
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.state = state
        self.started = started
        self.ended = ended
        self.durationSeconds = durationSeconds
        self.files = files
        self.startOffsetMs = startOffsetMs
        self.warnings = warnings
    }

    public var tracks: [SessionTrack] {
        var result: [SessionTrack] = []
        if let file = files["mic"] {
            result.append(SessionTrack(
                name: "mic",
                file: file,
                speaker: "me",
                offsetMs: startOffsetMs["mic"] ?? 0
            ))
        }
        if let file = files["system"] {
            result.append(SessionTrack(
                name: "system",
                file: file,
                speaker: "them",
                offsetMs: startOffsetMs["system"] ?? 0
            ))
        }
        return result
    }

    public func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self)
            .write(to: directory.appendingPathComponent("meta.json"), options: .atomic)
    }

    public static func read(from directory: URL) throws -> SessionMetadata {
        try JSONDecoder().decode(
            SessionMetadata.self,
            from: Data(contentsOf: directory.appendingPathComponent("meta.json"))
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case state
        case started
        case ended
        case durationSeconds = "duration_seconds"
        case files
        case startOffsetMs = "start_offset_ms"
        case warnings
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        state = try values.decodeIfPresent(SessionState.self, forKey: .state) ?? .pending
        started = try values.decode(String.self, forKey: .started)
        ended = try values.decodeIfPresent(String.self, forKey: .ended)
        durationSeconds = try values.decodeIfPresent(Int.self, forKey: .durationSeconds)
        files = try values.decode([String: String].self, forKey: .files)
        startOffsetMs = try values.decodeIfPresent(
            [String: Int].self,
            forKey: .startOffsetMs
        ) ?? [:]
        warnings = try values.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }
}

public struct TrackTranscriptCheckpoint: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let track: String
    public let file: String
    public let speaker: String
    public let offsetMs: Int
    public let engine: String
    public let engineVersion: String
    public let model: String
    public let requestedLanguage: LanguagePreference
    public let language: String
    public let languageSource: TranscriptLanguageSource
    public let createdAt: String
    public let segments: [RelativeTranscriptSegment]

    public init(
        track: String,
        file: String,
        speaker: String,
        offsetMs: Int,
        engine: String,
        engineVersion: String,
        model: String,
        requestedLanguage: LanguagePreference,
        language: String,
        languageSource: TranscriptLanguageSource,
        createdAt: String,
        segments: [RelativeTranscriptSegment],
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.track = track
        self.file = file
        self.speaker = speaker
        self.offsetMs = offsetMs
        self.engine = engine
        self.engineVersion = engineVersion
        self.model = model
        self.requestedLanguage = requestedLanguage
        self.language = language
        self.languageSource = languageSource
        self.createdAt = createdAt
        self.segments = segments
    }

    public func matches(
        _ sessionTrack: SessionTrack,
        engine: String,
        engineVersion: String,
        model: String,
        requestedLanguage: LanguagePreference
    ) -> Bool {
        track == sessionTrack.name
            && file == sessionTrack.file
            && speaker == sessionTrack.speaker
            && offsetMs == sessionTrack.offsetMs
            && self.engine == engine
            && self.engineVersion == engineVersion
            && self.model == model
            && self.requestedLanguage == requestedLanguage
    }

    public func write(to directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self)
            .write(
                to: directory.appendingPathComponent("\(track).json"),
                options: .atomic
            )
    }

    public static func read(track: String, from directory: URL) throws -> TrackTranscriptCheckpoint {
        try JSONDecoder().decode(
            TrackTranscriptCheckpoint.self,
            from: Data(contentsOf: directory.appendingPathComponent("\(track).json"))
        )
    }
}

public enum SessionQueue {
    public static func recoverInterruptedSessions(
        in root: URL,
        now: String
    ) throws -> [URL] {
        let sessions = try sessionDirectories(in: root)
        var recovered: [URL] = []
        for directory in sessions {
            guard var metadata = try? SessionMetadata.read(from: directory) else { continue }
            guard metadata.state == .recording else { continue }

            metadata.state = .pending
            metadata.ended = metadata.ended ?? now
            appendWarning(
                "recording was interrupted; available tracks will be transcribed",
                to: &metadata
            )
            try metadata.write(to: directory)
            recovered.append(directory)
        }
        return recovered
    }

    public static func pendingSessions(in root: URL) throws -> [URL] {
        try sessionDirectories(in: root)
            .filter { directory in
                guard let metadata = try? SessionMetadata.read(from: directory) else {
                    return false
                }
                return metadata.state == .pending || metadata.state == .transcribing
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public static func appendWarning(_ warning: String, to metadata: inout SessionMetadata) {
        guard !metadata.warnings.contains(warning) else { return }
        metadata.warnings.append(warning)
    }

    private static func sessionDirectories(in root: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }
}
