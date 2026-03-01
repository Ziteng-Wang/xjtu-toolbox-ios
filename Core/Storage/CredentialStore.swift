import Foundation
import Security

struct StoredCredential {
    let username: String
    let password: String
}

actor CredentialStore {
    static let shared = CredentialStore()

    private let service = "com.xjtu.toolbox.ios"
    private let defaults = UserDefaults.standard

    func saveCredential(username: String, password: String) {
        saveKeychain(value: username, account: AppConstants.StorageKey.username)
        saveKeychain(value: password, account: AppConstants.StorageKey.password)
    }

    func loadCredential() -> StoredCredential? {
        guard let username = loadKeychain(account: AppConstants.StorageKey.username),
              let password = loadKeychain(account: AppConstants.StorageKey.password),
              !username.isEmpty,
              !password.isEmpty else {
            return nil
        }
        return StoredCredential(username: username, password: password)
    }

    func clearAll() {
        deleteKeychain(account: AppConstants.StorageKey.username)
        deleteKeychain(account: AppConstants.StorageKey.password)
        defaults.removeObject(forKey: AppConstants.StorageKey.visitorID)
        defaults.removeObject(forKey: AppConstants.StorageKey.rsaPublicKey)
        defaults.removeObject(forKey: AppConstants.StorageKey.rsaPublicKeyTime)
    }

    func saveVisitorID(_ value: String) {
        defaults.set(value, forKey: AppConstants.StorageKey.visitorID)
    }

    func loadVisitorID() -> String? {
        defaults.string(forKey: AppConstants.StorageKey.visitorID)
    }

    func saveRSAPublicKey(_ key: String) {
        defaults.set(key, forKey: AppConstants.StorageKey.rsaPublicKey)
        defaults.set(Date().timeIntervalSince1970, forKey: AppConstants.StorageKey.rsaPublicKeyTime)
    }

    func loadRSAPublicKey(maxAge: TimeInterval = 24 * 3600) -> String? {
        let timestamp = defaults.double(forKey: AppConstants.StorageKey.rsaPublicKeyTime)
        guard timestamp > 0,
              Date().timeIntervalSince1970 - timestamp <= maxAge else {
            return nil
        }
        return defaults.string(forKey: AppConstants.StorageKey.rsaPublicKey)
    }

    private func saveKeychain(value: String, account: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func loadKeychain(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func deleteKeychain(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
