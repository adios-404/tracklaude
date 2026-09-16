import Foundation
import os
import TracklaudeCore

/// The app's only route to the unified log. This is the one file that may import `os` or
/// construct an `os.Logger` (`Scripts/check-log-redaction.sh` enforces it in CI), so every
/// message passes through `LogRedactor` before it leaves the process — a Credential can't
/// reach `log show` by way of a call site that forgot.
///
/// Messages are logged `.public` on purpose: the app writes no log files and the redactor
/// has already removed anything secret, so the owner can read their own poll log in full.
struct AppLog: Sendable {
    static let subsystem = Bundle.main.bundleIdentifier ?? "tracklaude"

    private let logger: Logger

    init(category: String) {
        logger = Logger(subsystem: Self.subsystem, category: category)
    }

    func notice(_ message: String) {
        logger.notice("\(LogRedactor.redact(message), privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(LogRedactor.redact(message), privacy: .public)")
    }

    func fault(_ message: String) {
        logger.fault("\(LogRedactor.redact(message), privacy: .public)")
    }
}
