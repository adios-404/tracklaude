import Foundation
import Security
import TracklaudeCore

/// Production CredentialStore: one generic-password item in the user's login Keychain,
/// service = bundle id, account `credential`. The refresh token is the item's data.
struct KeychainCredentialStore: CredentialStore {
    static let account = "credential"

    let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.adios404.tracklaude") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
        ]
    }

    func load() async throws -> Credential? {
        var query = baseQuery
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
        var add = baseQuery
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let update = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(updateStatus) }
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete() async throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case corruptItem
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .corruptItem:
            return "The stored Credential could not be read."
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Keychain: \(message)"
        }
    }
}
