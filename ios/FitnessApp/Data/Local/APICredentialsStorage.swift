import Foundation
import Security

struct APICredentials: Equatable, Sendable {
    var serverURL: URL
    var token: String
}

enum APICredentialsStorage {
    private static let serverURLKey = "fitness.api.server-url"

    static func load() throws -> APICredentials? {
        guard let serverURLValue = UserDefaults.standard.string(forKey: serverURLKey),
              let serverURL = URL(string: serverURLValue),
              let token = try KeychainAPIToken.load() else {
            return nil
        }

        return APICredentials(serverURL: serverURL, token: token)
    }

    static func save(_ credentials: APICredentials) throws {
        try KeychainAPIToken.save(credentials.token)
        UserDefaults.standard.set(credentials.serverURL.absoluteString, forKey: serverURLKey)
    }

    static func clear() throws {
        try KeychainAPIToken.clear()
        UserDefaults.standard.removeObject(forKey: serverURLKey)
    }
}

private enum KeychainAPIToken {
    private static let account = "api-token"
    private static let service = Bundle.main.bundleIdentifier ?? "com.jonton11.fitnessapp"

    static func load() throws -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne
            ] as CFDictionary,
            &item
        )

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw APICredentialsStorageError.keychain(status)
        }
        return token
    }

    static func save(_ token: String) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary
        let attributes = [
            kSecValueData: Data(token.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as CFDictionary
        let updateStatus = SecItemUpdate(query, attributes)

        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw APICredentialsStorageError.keychain(updateStatus)
        }

        let addStatus = SecItemAdd(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecValueData: Data(token.utf8),
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ] as CFDictionary,
            nil
        )
        guard addStatus == errSecSuccess else {
            throw APICredentialsStorageError.keychain(addStatus)
        }
    }

    static func clear() throws {
        let status = SecItemDelete(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account
            ] as CFDictionary
        )
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APICredentialsStorageError.keychain(status)
        }
    }
}

enum APICredentialsStorageError: Error {
    case keychain(OSStatus)
}
