import Foundation

public enum LanguagePreference: String, CaseIterable, Codable, Sendable {
    case automatic
    case portuguese = "pt"
    case english = "en"

    public var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .portuguese: return "Portuguese (Brazil)"
        case .english: return "English"
        }
    }

    public var whisperHint: String? {
        switch self {
        case .automatic: return nil
        case .portuguese: return "pt"
        case .english: return "en"
        }
    }
}

public enum TranscriptLanguageSource: String, Codable, Sendable {
    case detected
    case userHint = "user_hint"
}

public struct EngineTranscript: Equatable, Sendable {
    public let segments: [RelativeTranscriptSegment]
    public let language: String
    public let languageSource: TranscriptLanguageSource

    public init(
        segments: [RelativeTranscriptSegment],
        language: String,
        languageSource: TranscriptLanguageSource
    ) {
        self.segments = segments
        self.language = language
        self.languageSource = languageSource
    }
}

public struct TranscriptTrackInfo: Codable, Equatable, Sendable {
    public let name: String
    public let speaker: String
    public let language: String
    public let languageSource: TranscriptLanguageSource

    public init(
        name: String,
        speaker: String,
        language: String,
        languageSource: TranscriptLanguageSource
    ) {
        self.name = name
        self.speaker = speaker
        self.language = language
        self.languageSource = languageSource
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case speaker
        case language
        case languageSource = "language_source"
    }
}

public enum LanguageConfiguration {
    public static func read(from url: URL) -> LanguagePreference {
        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let transcription = object["transcription"] as? [String: Any],
            let rawValue = transcription["language"] as? String
        else {
            return .portuguese
        }
        return LanguagePreference(rawValue: rawValue) ?? .automatic
    }

    public static func write(_ preference: LanguagePreference, to url: URL) throws {
        var object: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            guard let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ConfigurationError.invalidJSON(url)
            }
            object = existing
        }

        var transcription = object["transcription"] as? [String: Any] ?? [:]
        transcription["language"] = preference.rawValue
        object["transcription"] = transcription

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: url, options: .atomic)
    }

    public enum ConfigurationError: Error, CustomStringConvertible {
        case invalidJSON(URL)

        public var description: String {
            switch self {
            case .invalidJSON(let url): return "invalid JSON configuration: \(url.path)"
            }
        }
    }
}
