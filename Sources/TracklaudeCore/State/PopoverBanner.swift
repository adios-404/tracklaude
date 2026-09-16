import Foundation

/// The banner above the popover rows: the plain-English reason and the one thing that
/// fixes it (spec › Popover). `nil` when there is nothing to explain.
///
/// Pure; the executable ticks `now` once a second while the popover is open so the
/// rate-limit countdown moves.
public struct PopoverBanner: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case signIn
        case retry
        case cancelSignIn

        public var title: String {
            switch self {
            case .signIn: return "Sign in"
            case .retry: return "Retry"
            case .cancelSignIn: return "Cancel"
            }
        }
    }

    public let message: String
    /// `nil` while backing off: nothing the user does can end a lockout sooner.
    public let action: Action?

    public init(message: String, action: Action?) {
        self.message = message
        self.action = action
    }

    /// - Parameter signInFailure: why the last sign-in attempt failed, shown only while
    ///   signed out so the user knows the button is worth pressing again.
    public static func render(state: AppState, signInFailure: String? = nil, now: Date) -> PopoverBanner? {
        switch state {
        case .polling:
            return nil
        case .signedOut:
            let message = signInFailure.map { "Sign-in failed: \($0)" } ?? "Not signed in."
            return PopoverBanner(message: message, action: .signIn)
        case .signingIn:
            return PopoverBanner(message: "Finish signing in in your browser…", action: .cancelSignIn)
        case .stale(_, .offline):
            return PopoverBanner(message: "Can't reach Anthropic. Check your connection.", action: .retry)
        case .stale(_, .serverError):
            return PopoverBanner(message: "Anthropic's usage service isn't answering properly.", action: .retry)
        case .stale(_, .sessionExpired):
            return PopoverBanner(message: "Your session expired. Sign in again.", action: .signIn)
        case .stale(_, .rateLimited):
            return PopoverBanner(message: rateLimited, action: .retry)
        case .backingOff(_, let until, _):
            let remaining = until.timeIntervalSince(now)
            let when = remaining > 0 ? "in \(countdown(remaining))." : "now…"
            return PopoverBanner(message: "\(rateLimited) Retrying \(when)", action: nil)
        }
    }

    private static let rateLimited = "Anthropic is rate-limiting usage checks."

    /// `4 min 59 s` / `59 s`: the same units the footer's "Updated" text uses. Rounds up so
    /// the count never reads 0 s while a wait remains.
    private static func countdown(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.up))
        let minutes = whole / 60
        let rest = whole % 60
        return minutes > 0 ? "\(minutes) min \(rest) s" : "\(rest) s"
    }
}
