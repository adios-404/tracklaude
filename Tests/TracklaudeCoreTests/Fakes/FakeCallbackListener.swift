import TracklaudeCore

/// Stands in for the loopback server: binds a fixed port and hands back a fixed code.
actor FakeCallbackListener: CallbackListener {
    let port: UInt16
    private let code: String
    private(set) var expectedState: String?

    init(port: UInt16 = 1456, code: String = "CODE") {
        self.port = port
        self.code = code
    }

    func start(expectedState: String) async throws -> UInt16 {
        self.expectedState = expectedState
        return port
    }

    func awaitCode() async throws -> String { code }
    func cancel() {}
}
