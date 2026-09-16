import Foundation
import Testing
import TracklaudeCore

// The signed-in session: holds the access token, refreshes it on 401, classifies every
// failure into one Stale reason. Driven through the transport and store seams only.
private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let credential = Credential(refreshToken: "sk-ant-ort01-OLD")

private func storeHolding(_ credential: Credential?) async -> InMemoryCredentialStore {
    let store = InMemoryCredentialStore()
    if let credential { try? await store.save(credential) }
    return store
}

private func usageRequests(_ transport: ScriptedTransport) async -> [HTTPRequest] {
    await transport.sent.filter { $0.url == UsageFetch.usageURL }
}

@Test("with an access token in hand, a 200 is one request and a Snapshot")
func fetchWithTokenIsOneRequest() async throws {
    let transport = ScriptedTransport([.success(try Fixture.response("usage-normal.http"))])
    let session = UsageSession(store: await storeHolding(credential), transport: transport, accessToken: "sk-ant-oat01-A")

    let result = await session.fetch(now: now)

    guard case .snapshot(let snapshot) = result else { Issue.record("expected a Snapshot, got \(result)"); return }
    #expect(snapshot.fiveHour?.utilization == 48)
    let sent = await transport.sent
    #expect(sent.count == 1)
    #expect(sent.first?.headers["Authorization"] == "Bearer sk-ant-oat01-A")
}

@Test("401 → refresh once → retry once with the new token → Snapshot")
func unauthorizedRefreshesAndRetries() async throws {
    let transport = ScriptedTransport([
        .success(try Fixture.response("usage-401.http")),
        .success(try Fixture.jsonResponse("oauth-token-response.json")),
        .success(try Fixture.response("usage-normal.http")),
    ])
    let session = UsageSession(store: await storeHolding(credential), transport: transport, accessToken: "sk-ant-oat01-DEAD")

    let result = await session.fetch(now: now)

    guard case .snapshot = result else { Issue.record("expected a Snapshot, got \(result)"); return }
    let usage = await usageRequests(transport)
    #expect(usage.map { $0.headers["Authorization"] } == ["Bearer sk-ant-oat01-DEAD", "Bearer sk-ant-oat01-ACCESS"])
}

@Test("the rotated refresh token is in the store before the retry is sent")
func rotationIsPersistedImmediately() async throws {
    let store = await storeHolding(credential)
    let transport = ScriptedTransport([
        .success(try Fixture.response("usage-401.http")),
        .success(try Fixture.jsonResponse("oauth-token-response.json")),
        .success(try Fixture.response("usage-normal.http")),
    ])
    let session = UsageSession(store: store, transport: transport, accessToken: "sk-ant-oat01-DEAD")

    _ = await session.fetch(now: now)

    let stored = try await store.load()
    #expect(stored == Credential(refreshToken: "sk-ant-ort01-REFRESH"))
}

@Test("401 and the refresh is refused (invalid_grant) → session expired, no retry")
func refreshRefusedIsSessionExpired() async throws {
    let transport = ScriptedTransport([
        .success(try Fixture.response("usage-401.http")),
        .success(.json(status: 400, #"{"error":"invalid_grant"}"#)),
    ])
    let session = UsageSession(store: await storeHolding(credential), transport: transport, accessToken: "sk-ant-oat01-DEAD")

    let result = await session.fetch(now: now)

    #expect(result == .failed(.sessionExpired))
    #expect(await transport.sent.count == 2)
}

@Test("401 even after a fresh token → session expired: the sign-in itself is not accepted")
func unauthorizedAfterRefreshIsSessionExpired() async throws {
    let transport = ScriptedTransport([
        .success(try Fixture.response("usage-401.http")),
        .success(try Fixture.jsonResponse("oauth-token-response.json")),
        .success(try Fixture.response("usage-401.http")),
    ])
    let session = UsageSession(store: await storeHolding(credential), transport: transport, accessToken: "sk-ant-oat01-DEAD")

    #expect(await session.fetch(now: now) == .failed(.sessionExpired))
}

@Test("no access token yet (fresh launch) → refresh first, then fetch")
func noTokenRefreshesFirst() async throws {
    let transport = ScriptedTransport([
        .success(try Fixture.jsonResponse("oauth-token-response.json")),
        .success(try Fixture.response("usage-normal.http")),
    ])
    let session = UsageSession(store: await storeHolding(credential), transport: transport)

    let result = await session.fetch(now: now)

    guard case .snapshot = result else { Issue.record("expected a Snapshot, got \(result)"); return }
    let sent = await transport.sent
    #expect(sent.map(\.url) == [OAuthConfig.tokenURL, UsageFetch.usageURL])
}

@Test("no token and no Credential in the store → session expired without touching the network")
func noCredentialIsSessionExpired() async {
    let transport = ScriptedTransport([])
    let session = UsageSession(store: await storeHolding(nil), transport: transport)

    #expect(await session.fetch(now: now) == .failed(.sessionExpired))
    #expect(await transport.sent.isEmpty)
}

@Test("a network error on the usage request → offline")
func networkErrorIsOffline() async {
    let transport = ScriptedTransport([.failure(NetworkDown())])
    let session = UsageSession(store: await storeHolding(credential), transport: transport, accessToken: "T")

    #expect(await session.fetch(now: now) == .failed(.offline))
}

@Test("a network error on the refresh → offline, not expired: the Credential may be fine")
func networkErrorDuringRefreshIsOffline() async {
    let transport = ScriptedTransport([.failure(NetworkDown())])
    let session = UsageSession(store: await storeHolding(credential), transport: transport)

    #expect(await session.fetch(now: now) == .failed(.offline))
}

@Test("the recorded 429 → rate limited with its Retry-After")
func rateLimitedCarriesRetryAfter() async throws {
    let transport = ScriptedTransport([.success(try Fixture.response("usage-429.http"))])
    let session = UsageSession(store: await storeHolding(credential), transport: transport, accessToken: "T")

    #expect(await session.fetch(now: now) == .failed(.rateLimited(retryAfter: 300)))
}

@Test("5xx, an HTML challenge page and an undecodable body all read as a server error")
func serverSideFailuresAreServerError() async throws {
    for reply in [try Fixture.response("usage-5xx.http"), try Fixture.response("usage-html.http"), .json(status: 200, "[]")] {
        let transport = ScriptedTransport([.success(reply)])
        let session = UsageSession(store: await storeHolding(credential), transport: transport, accessToken: "T")
        let result = await session.fetch(now: now)
        #expect(result == .failed(.serverError), "for HTTP \(reply.status)")
    }
}

@Test("a refresh that fails on the server's side is a server error, not an expired session")
func refreshServerErrorIsServerError() async throws {
    let transport = ScriptedTransport([
        .success(try Fixture.response("usage-401.http")),
        .success(.json(status: 503, "{}")),
    ])
    let session = UsageSession(store: await storeHolding(credential), transport: transport, accessToken: "T")

    #expect(await session.fetch(now: now) == .failed(.serverError))
}

@Test("a token adopted after sign-in is used as-is, with no refresh")
func adoptedTokenIsUsed() async throws {
    let transport = ScriptedTransport([.success(try Fixture.response("usage-normal.http"))])
    let session = UsageSession(store: await storeHolding(credential), transport: transport)
    await session.adopt(accessToken: "sk-ant-oat01-FRESH")

    _ = await session.fetch(now: now)

    #expect(await transport.sent.first?.headers["Authorization"] == "Bearer sk-ant-oat01-FRESH")
}
