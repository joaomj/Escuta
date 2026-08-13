import Foundation
import EscutaCore

func runLanguageConfigurationTests() throws {
    try testLanguageDisplayAndWhisperHints()
    try testLanguagePreferenceRoundTrip()
    try testInvalidLanguageDefaultsToAutomatic()
    try testWritingLanguagePreservesConfiguration()
}

private func testLanguageDisplayAndWhisperHints() throws {
    try expect(LanguagePreference.automatic.displayName == "Automatic", "automatic display name")
    try expect(LanguagePreference.portuguese.displayName == "Portuguese (Brazil)", "Portuguese display name")
    try expect(LanguagePreference.english.displayName == "English", "English display name")
    try expect(LanguagePreference.automatic.whisperHint == nil, "automatic Whisper hint")
    try expect(LanguagePreference.portuguese.whisperHint == "pt", "Portuguese Whisper hint")
    try expect(LanguagePreference.english.whisperHint == "en", "English Whisper hint")
}

private func testLanguagePreferenceRoundTrip() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("config.json")

    for preference in LanguagePreference.allCases {
        try LanguageConfiguration.write(preference, to: file)
        try expect(
            LanguageConfiguration.read(from: file) == preference,
            "language round trip \(preference.rawValue)"
        )
    }
}

private func testInvalidLanguageDefaultsToAutomatic() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("config.json")
    let json: [String: Any] = ["transcription": ["language": "fr"]]
    try JSONSerialization.data(withJSONObject: json).write(to: file)

    try expect(
        LanguageConfiguration.read(from: file) == .automatic,
        "invalid language defaults to automatic"
    )
}

private func testWritingLanguagePreservesConfiguration() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("config.json")
    let json: [String: Any] = [
        "recordings_dir": "~/Recordings",
        "transcription": ["enabled": true],
    ]
    try JSONSerialization.data(withJSONObject: json).write(to: file)

    try LanguageConfiguration.write(.portuguese, to: file)
    let result = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
    let transcription = result?["transcription"] as? [String: Any]

    try expect(result?["recordings_dir"] as? String == "~/Recordings", "preserved recordings directory")
    try expect(transcription?["enabled"] as? Bool == true, "preserved transcription setting")
    try expect(transcription?["language"] as? String == "pt", "written language")
}

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("escuta-language-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
