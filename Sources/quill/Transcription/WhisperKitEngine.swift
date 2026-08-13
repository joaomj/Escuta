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

    func transcribe(_ audio: URL) async throws -> [RelativeTranscriptSegment] {
        guard let whisperKit else { throw EngineError.notPrepared }
        try validateAudio(audio)

        let options = DecodingOptions(
            task: .transcribe,
            detectLanguage: true,
            wordTimestamps: false
        )
        let input = AudioInputOptions(audioLoadingMode: .incremental)
        let results = try await whisperKit.transcribe(
            audioPath: audio.path,
            audioInputOptions: input,
            decodeOptions: options,
            callback: { progress in
                FileHandle.standardError.write(Data(
                    "whisperkit progress window \(progress.windowId)\n".utf8
                ))
                return true
            }
        )
        guard !results.isEmpty else { throw EngineError.noResults(audio) }

        return results.flatMap { result in
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
}
