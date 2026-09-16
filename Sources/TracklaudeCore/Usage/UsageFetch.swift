import Foundation

/// Why a fetch produced no Snapshot. Each case maps to one Stale reason or recovery path.
public enum UsageFetchError: Error, Equatable, Sendable, LocalizedError {
    /// 401: the access token is dead. Refresh once and retry before giving up.
    case unauthorized
    /// 429: back off; `retryAfter` is the server's `Retry-After` in seconds, when sent.
    case rateLimited(retryAfter: TimeInterval?)
    /// 5xx.
    case serverError(status: Int)
    /// Any status whose body is not the usage shape (HTML challenge pages included).
    case undecodable(status: Int)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: return "Anthropic no longer accepts the sign-in."
        case .rateLimited: return "Anthropic is rate-limiting usage checks."
        case .serverError(let status): return "Anthropic's usage service returned HTTP \(status)."
        case .undecodable(let status): return "Anthropic's usage reply (HTTP \(status)) was not in the expected format."
        }
    }
}

/// One usage fetch: GET the endpoint with the access token, decode the Snapshot.
///
/// No browser-impersonating headers, ever (spec › Fetching usage).
public enum UsageFetch {
    public static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let betaHeader = "oauth-2025-04-20"

    public static func perform(
        accessToken: String,
        transport: any UsageTransport,
        now: Date
    ) async throws -> Snapshot {
        let request = HTTPRequest(
            method: "GET",
            url: usageURL,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "anthropic-beta": betaHeader,
            ]
        )
        let response = try await transport.send(request)
        switch response.status {
        case 401:
            throw UsageFetchError.unauthorized
        case 429:
            throw UsageFetchError.rateLimited(retryAfter: retryAfter(in: response.headers))
        case 500...599:
            throw UsageFetchError.serverError(status: response.status)
        default:
            do {
                return try UsageDecoder.decode(response.body, fetchedAt: now)
            } catch {
                throw UsageFetchError.undecodable(status: response.status)
            }
        }
    }

    /// Header names arrive in whatever case the server used.
    private static func retryAfter(in headers: [String: String]) -> TimeInterval? {
        headers.first { $0.key.caseInsensitiveCompare("Retry-After") == .orderedSame }
            .flatMap { TimeInterval($0.value.trimmingCharacters(in: .whitespaces)) }
    }
}
