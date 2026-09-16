import Foundation
import Testing
import TracklaudeCore

private let tokenResponse = "oauth-token-response.json"

/// Records the URL handed to the browser.
private actor BrowserSpy {
    private(set) var opened: [URL] = []
    func open(_ url: URL) { opened.append(url) }
}

private func makeSignIn(
    transport: FakeTransport,
    store: InMemoryCredentialStore,
    listener: FakeCallbackListener = FakeCallbackListener(),
    browser: BrowserSpy = BrowserSpy()
) -> SignIn {
    SignIn(
        randomOctets: { count in Array(repeating: 7, count: count) },
        listener: listener,
        openURL: { url in await browser.open(url) },
        transport: transport,
        store: store
    )
}

@Test("after sign-in the refresh token is the stored Credential")
func signInStoresRefreshTokenAsCredential() async throws {
    let store = InMemoryCredentialStore()
    let signIn = makeSignIn(transport: FakeTransport(replying: try Fixture.jsonResponse(tokenResponse)), store: store)

    _ = try await signIn.run()

    #expect(try await store.load() == Credential(refreshToken: "sk-ant-ort01-REFRESH"))
}

@Test("the browser is sent to an authorize URL whose redirect uses the bound port and whose state the listener expects")
func signInOpensBrowserWiredToTheListener() async throws {
    let listener = FakeCallbackListener(port: 1458)
    let browser = BrowserSpy()
    let signIn = makeSignIn(
        transport: FakeTransport(replying: try Fixture.jsonResponse(tokenResponse)), store: InMemoryCredentialStore(),
        listener: listener, browser: browser
    )

    _ = try await signIn.run()

    let url = try #require(await browser.opened.first)
    let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value) })
    #expect(query["redirect_uri"] == "http://localhost:1458/callback")
    #expect(query["state"] != nil)
    #expect(query["state"] == (await listener.expectedState))
}

@Test("when the code exchange fails nothing is stored")
func failedExchangeStoresNothing() async throws {
    let store = InMemoryCredentialStore()
    let signIn = makeSignIn(transport: FakeTransport(replying: .json(status: 400, "{}")), store: store)

    await #expect(throws: OAuthTokenError.httpStatus(400)) { try await signIn.run() }

    #expect(try await store.load() == nil)
}
