import Foundation
import Testing
import TracklaudeCore

/// Recorded responses under `Fixtures/`, shipped as test-target resources.
enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    /// A 200 JSON response whose body is the named fixture.
    static func jsonResponse(_ name: String) throws -> HTTPResponse {
        HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: try data(name))
    }
}
