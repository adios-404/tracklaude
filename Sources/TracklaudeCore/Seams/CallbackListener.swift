/// The loopback HTTP listener that receives the browser's redirect during sign-in.
///
/// Production adapter binds 127.0.0.1 and ::1 (in the executable); tests use a fake.
public protocol CallbackListener: Sendable {
    /// Starts listening for one `/callback` carrying `expectedState`. Returns the bound port.
    func start(expectedState: String) async throws -> UInt16
    /// Resolves with the authorization code from the first accepted callback, then stops.
    func awaitCode() async throws -> String
    /// Stops listening without a callback (sign-in abandoned or failed).
    func cancel() async
}
