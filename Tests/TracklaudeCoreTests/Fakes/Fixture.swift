import Foundation
import Testing
import TracklaudeCore

/// Recorded responses under `Fixtures/`, shipped as test-target resources.
///
/// `.http` fixtures are whole responses — status line, headers, blank line, body — so a
/// test replays exactly what the transport would have returned, headers included.
enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    /// A 200 JSON response whose body is the named fixture.
    static func jsonResponse(_ name: String) throws -> HTTPResponse {
        HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: try data(name))
    }

    /// The whole recorded response in a `.http` fixture.
    static func response(_ name: String) throws -> HTTPResponse {
        let raw = try data(name)
        let separator = Data("\r\n\r\n".utf8)
        let headerEnd = try #require(raw.range(of: separator))
        let head = try #require(String(data: raw[..<headerEnd.lowerBound], encoding: .utf8))
        let lines = head.components(separatedBy: "\r\n")
        let status = try #require(lines.first?.split(separator: " ").dropFirst().first.flatMap { Int($0) })
        let headers = Dictionary(
            lines.dropFirst().compactMap { line -> (String, String)? in
                guard let colon = line.firstIndex(of: ":") else { return nil }
                return (String(line[..<colon]), line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
            },
            uniquingKeysWith: { first, _ in first }
        )
        return HTTPResponse(status: status, headers: headers, body: raw[headerEnd.upperBound...])
    }

    /// Only the body of a `.http` fixture.
    static func body(_ name: String) throws -> Data {
        try response(name).body
    }
}
