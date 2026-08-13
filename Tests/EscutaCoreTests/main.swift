import Foundation

do {
    try runTranscriptTests()
    try runSessionMetadataTests()
    try runSessionQueueTests()
    print("EscutaCoreTests: all tests passed")
} catch {
    FileHandle.standardError.write(Data("EscutaCoreTests: \(error)\n".utf8))
    exit(1)
}
