import AVFoundation
import EscutaCore
import Foundation
import WhisperKit

/// Local multilingual Whisper transcription through WhisperKit's Core ML port.
/// The model is loaded only while the transcription queue has work.
actor WhisperKitEngine: TranscriptionEngine {
    enum EngineError: Error, CustomStringConvertible {
        case notPrepared
        case unreadableAudio(URL, Error?)
        case noResults(URL)

        var description: String {
            switch self {
            case .notPrepared:
                return "whisperkit engine used before prepare()"
            case .unreadableAudio(let url, let error):
                return "unreadable or empty audio \(url.lastPathComponent)"
                    + (error.map { ": \($0)" } ?? "")
            case .noResults(let url):
                return "whisperkit returned no results for \(url.lastPathComponent)"
            }
        }
    }

    nonisolated let name = "whisperkit"
    nonisolated let version = "1.1.0"
    nonisolated let model: String

    private let modelFolder: URL
    private let tokenizerFolder: URL
    private var whisperKit: WhisperKit?

    init(
        model: String = Config.whisperModel(),
        modelFolder: URL? = nil,
        tokenizerFolder: URL = Config.whisperTokenizerFolder()
    ) {
        self.model = model
        self.modelFolder = modelFolder ?? Config.whisperModelFolder(model: model)
        self.tokenizerFolder = tokenizerFolder
    }

    func prepare() async throws {
        guard whisperKit == nil else { return }

        let config = WhisperKitConfig(
            model: model,
            modelFolder: modelFolder.path,
            tokenizerFolder: tokenizerFolder,
            verbose: false,
            load: false,
            download: false
        )
        let kit = try await WhisperKit(config)
        try await kit.loadModels()
        whisperKit = kit
    }

    /// Download model and tokenizer files only after an explicit user action.
    /// WhisperKit stores downloads in a Hub cache, so completed files are moved
    /// into Escuta's stable, documented cache paths after each download.
    static func download(
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let staging = Config.whisperDownloadStagingFolder()
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

        let downloadedModel = try await WhisperKit.download(
            variant: Config.whisperModel(),
            downloadBase: staging,
            progressCallback: { update in
                progress(min(update.fractionCompleted * 0.9, 0.9))
            }
        )
        try installModel(from: downloadedModel, to: Config.whisperModelFolder())

        let hub = HubApiWrapper(downloadBase: staging)
        let tokenizerRepo = HubApiWrapper.Repo(id: Config.whisperTokenizerRepository())
        _ = try await hub.snapshot(
            from: tokenizerRepo,
            matching: ["tokenizer.json", "tokenizer_config.json"]
        ) { update in
            progress(0.9 + update.fractionCompleted * 0.1)
        }
        try installTokenizer(
            from: hub.localRepoLocation(tokenizerRepo),
            to: Config.whisperTokenizerFolder()
        )
        progress(1)
    }

    func transcribe(
        _ audio: URL,
        language: LanguagePreference,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> EngineTranscript {
        guard let whisperKit else { throw EngineError.notPrepared }
        try validateAudio(audio)

        let options = DecodingOptions(
            task: .transcribe,
            language: language.whisperHint,
            detectLanguage: language == .automatic,
            wordTimestamps: false
        )
        let input = AudioInputOptions(audioLoadingMode: .incremental)
        let results = try await whisperKit.transcribe(
            audioPath: audio.path,
            audioInputOptions: input,
            decodeOptions: options,
            callback: { update in
                FileHandle.standardError.write(Data(
                    "whisperkit progress window \(update.windowId)\n".utf8
                ))
                let text = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
                progress(text.isEmpty ? "window \(update.windowId)" : text)
                return true
            }
        )
        guard !results.isEmpty else { throw EngineError.noResults(audio) }

        let segments: [RelativeTranscriptSegment] = results.flatMap { result in
            result.segments.compactMap { segment in
                let text = segment.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return RelativeTranscriptSegment(
                    start: TimeInterval(segment.start),
                    end: TimeInterval(segment.end),
                    text: text
                )
            }
        }
        let detectedLanguage = language.whisperHint ?? results.first?.language ?? "unknown"
        return EngineTranscript(
            segments: segments,
            language: detectedLanguage,
            languageSource: language == .automatic ? .detected : .userHint
        )
    }

    func release() async {
        guard let whisperKit else { return }
        await whisperKit.unloadModels()
        self.whisperKit = nil
    }

    private func validateAudio(_ audio: URL) throws {
        do {
            let probe = try AVAudioFile(forReading: audio)
            guard probe.length > 0 else { throw EngineError.unreadableAudio(audio, nil) }
        } catch let error as EngineError {
            throw error
        } catch {
            throw EngineError.unreadableAudio(audio, error)
        }
    }

    private static func installModel(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: source, to: destination)
    }

    private static func installTokenizer(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let files = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for file in files {
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            let target = destination.appendingPathComponent(file.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.copyItem(at: file, to: target)
        }
    }
}
