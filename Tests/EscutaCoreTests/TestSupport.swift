import Foundation

func expect(_ condition: Bool, _ name: String) throws {
    guard condition else { throw TestFailure(name: name) }
}

struct TestFailure: Error, CustomStringConvertible {
    let name: String

    var description: String { "failed: \(name)" }
}
