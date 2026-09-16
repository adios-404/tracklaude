import Foundation
import Security
import TracklaudeCore

/// Production CredentialStore: one generic-password item in the user's login Keychain,
/// service = bundle id, account `credential`. The refresh token is the item's data.
struct KeychainCredentialStore: CredentialStore {
    static let account = "credential"

    /// The bundle id from Info.plist (stamped by the Makefile, the single source of ids).
    /// Nil only when the binary runs outside a bundle, e.g. `swift run`; every operation then fails.
    private let service = Bundle.main.bundleIdentifier

    private func baseQuery() throws -> [String: Any] {
        guard let service else { throw KeychainError.noBundleIdentifier }
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
        ]
    }

    func load() async throws -> Credential? {
        var query = try baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
                throw KeychainError.corruptItem
            }
            return Credential(refreshToken: token)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func save(_ credential: Credential) async throws {
        let data = Data(credential.refreshToken.utf8)
        let query = try baseQuery()
        var add = query
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let update = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(updateStatus) }
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete() async throws {
        let status = SecItemDelete(try baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case noBundleIdentifier
    case corruptItem
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noBundleIdentifier:
            return "Not running from an app bundle, so there is no Keychain service name."
        case .corruptItem:
            return "The stored Credential could not be read."
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Keychain: \(message)"
        }
    }
}
