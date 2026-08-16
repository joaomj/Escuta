import Foundation
import EscutaCore

/// Optional user config at ~/.config/quill/config.json:
///
///     {
///       "recordings_dir": "~/Recordings",
///       "transcription": {
///         "enabled": true,
///         "engine": "whisperkit",
///         "language": "pt"
///       },
///       "mic_voice_processing": true,
///       "on_stop": "my-hook"
///     }
///
/// Resolution order for the recordings root: --out flag > config file >
/// ~/Recordings. `on_stop` is a shell command spawned with the session
/// directory as its argument — after the transcript is written, or right
/// after recording when transcription is disabled.
enum Config {
    static let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/quill/config.json")

    static let defaultRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Recordings", isDirectory: true)

    /// The configured recordings root, or nil if no config file / no key.
    static func recordingsDir() -> URL? {
        guard let dir = load()?["recordings_dir"] as? String, !dir.isEmpty else { return nil }
        return URL(fileURLWithPath: (dir as NSString).expandingTildeInPath, isDirectory: true)
    }

    /// Shell command to spawn after each session's transcript is written (or
    /// after recording, if transcription is disabled), or nil.
    static func onStop() -> String? {
        guard let cmd = load()?["on_stop"] as? String, !cmd.isEmpty else { return nil }
        return cmd
    }

    /// Whether finished recordings are transcribed automatically. Default on.
    static func transcriptionEnabled() -> Bool {
        transcription()?["enabled"] as? Bool ?? true
    }

    /// Configured engine name. Only "whisperkit" ships today; the coordinator
    /// warns and falls back for anything else.
    static func transcriptionEngine() -> String {
        transcription()?["engine"] as? String ?? "whisperkit"
    }

    static func languagePreference() -> LanguagePreference {
        LanguageConfiguration.read(from: path)
    }

    static func setLanguagePreference(_ preference: LanguagePreference) throws {
        try LanguageConfiguration.write(preference, to: path)
    }

    static let productionWhisperModel = "large-v3-v20240930_626MB"
    static let developmentWhisperModel = "tiny"

    static func whisperModel() -> String {
        guard let configured = transcription()?["model"] as? String else {
            return productionWhisperModel
        }
        switch configured {
        case productionWhisperModel, developmentWhisperModel:
            return configured
        default:
            FileHandle.standardError.write(Data(
                "warning: unsupported WhisperKit model \"\(configured)\" — using \(productionWhisperModel)\n".utf8
            ))
            return productionWhisperModel
        }
    }

    static func whisperModelFolder(model: String = whisperModel()) -> URL {
        modelRoot().appendingPathComponent("openai_whisper_\(model)", isDirectory: true)
    }

    static func whisperTokenizerFolder() -> URL {
        modelRoot().appendingPathComponent("tokenizer", isDirectory: true)
    }

    static func whisperModelApproximateSize() -> String {
        whisperModel() == developmentWhisperModel ? "about 75 MB" : "about 626 MB"
    }

    static func whisperModelDestination() -> URL {
        whisperModelFolder()
    }

    static func whisperModelIsLocal() -> Bool {
        modelFilesExist(at: whisperModelFolder())
            && FileManager.default.fileExists(
                atPath: whisperTokenizerFolder().appendingPathComponent("tokenizer.json").path
            )
    }

    static func whisperTokenizerRepository() -> String {
        whisperModel() == developmentWhisperModel
            ? "openai/whisper-tiny"
            : "openai/whisper-large-v3"
    }

    static func whisperDownloadStagingFolder() -> URL {
        modelRoot().appendingPathComponent(".download", isDirectory: true)
    }

    private static func modelRoot() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/quill/WhisperKit", isDirectory: true)
    }

    private static func modelFilesExist(at directory: URL) -> Bool {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return false }
        return ["MelSpectrogram", "AudioEncoder", "TextDecoder"].allSatisfy { name in
            files.contains { $0.lastPathComponent.hasPrefix(name) }
        }
    }

    private static func transcription() -> [String: Any]? {
        load()?["transcription"] as? [String: Any]
    }

    /// Apple voice processing (acoustic echo cancellation) on the mic, so
    /// speaker playback doesn't bleed into the mic track and get transcribed
    /// as "me". Default off — the live voice unit ducks all other playback,
    /// and on headphones there's no echo to cancel anyway. Set true when
    /// recording meetings through the speakers.
    static func micVoiceProcessing() -> Bool {
        load()?["mic_voice_processing"] as? Bool ?? false
    }

    /// Parse the config file. A malformed config is reported on stderr rather
    /// than silently ignored — recordings landing in an unexpected place is
    /// worse than a warning.
    private static func load() -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        guard
            let data = try? Data(contentsOf: path),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            FileHandle.standardError.write(Data(
                "warning: \(path.path) is not valid JSON — ignoring config\n".utf8
            ))
            return nil
        }
        return json
    }

    /// Resolve the recordings root from an optional CLI override.
    static func resolveRoot(cliOverride: String?) -> URL {
        if let cliOverride {
            return URL(
                fileURLWithPath: (cliOverride as NSString).expandingTildeInPath,
                isDirectory: true
            )
        }
        return recordingsDir() ?? defaultRoot
    }
}
