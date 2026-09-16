import Foundation
import Testing
import TracklaudeCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

@Test("usage is fetched with a bearer token and the oauth beta header, nothing else")
func fetchSendsBearerAndBetaHeader() async throws {
    let transport = FakeTransport(replying: try Fixture.response("usage-normal.http"))

    _ = try await UsageFetch.perform(accessToken: "sk-ant-oat01-ACCESS", transport: transport, now: now)

    let request = try #require(await transport.sent.first)
    #expect(request.method == "GET")
    #expect(request.url.absoluteString == "https://api.anthropic.com/api/oauth/usage")
    #expect(request.headers == [
        "Authorization": "Bearer sk-ant-oat01-ACCESS",
        "anthropic-beta": "oauth-2025-04-20",
    ])
    #expect(request.body == nil)
}

@Test("a 200 becomes a Snapshot stamped with the fetch time")
func fetchDecodesSnapshot() async throws {
    let transport = FakeTransport(replying: try Fixture.response("usage-normal.http"))

    let snapshot = try await UsageFetch.perform(accessToken: "T", transport: transport, now: now)

    #expect(snapshot.fetchedAt == now)
    #expect(snapshot.fiveHour?.utilization == 42)
}

@Test("a 401 is reported as unauthorized so the caller can refresh and retry")
func fetchReports401() async throws {
    let transport = FakeTransport(replying: try Fixture.response("usage-401.http"))

    await #expect(throws: UsageFetchError.unauthorized) {
        try await UsageFetch.perform(accessToken: "T", transport: transport, now: now)
    }
}

@Test("a 429 is reported as rate-limited, carrying Retry-After in seconds")
func fetchReports429WithRetryAfter() async throws {
    let transport = FakeTransport(replying: try Fixture.response("usage-429.http"))

    await #expect(throws: UsageFetchError.rateLimited(retryAfter: 17)) {
        try await UsageFetch.perform(accessToken: "T", transport: transport, now: now)
    }
}

@Test("a 429 without Retry-After is still rate-limited, with no hint")
func fetchReports429WithoutRetryAfter() async throws {
    let transport = FakeTransport(replying: .json(status: 429, "{}"))

    await #expect(throws: UsageFetchError.rateLimited(retryAfter: nil)) {
        try await UsageFetch.perform(accessToken: "T", transport: transport, now: now)
    }
}

@Test("a 5xx is reported as a server error with its status")
func fetchReports5xx() async throws {
    let transport = FakeTransport(replying: try Fixture.response("usage-5xx.http"))

    await #expect(throws: UsageFetchError.serverError(status: 503)) {
        try await UsageFetch.perform(accessToken: "T", transport: transport, now: now)
    }
}

@Test("an HTML body, whatever the status, is reported as undecodable")
func fetchReportsHTMLBody() async throws {
    let transport = FakeTransport(replying: try Fixture.response("usage-html.http"))

    await #expect(throws: UsageFetchError.undecodable(status: 403)) {
        try await UsageFetch.perform(accessToken: "T", transport: transport, now: now)
    }
}

@Test("a 200 whose body is not usage JSON is reported as undecodable")
func fetchReports200WithBadBody() async throws {
    let transport = FakeTransport(replying: .json(status: 200, "[]"))

    await #expect(throws: UsageFetchError.undecodable(status: 200)) {
        try await UsageFetch.perform(accessToken: "T", transport: transport, now: now)
    }
}
