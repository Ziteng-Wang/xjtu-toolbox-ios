import Foundation

actor CookiePersistence {
    static let shared = CookiePersistence()

    private let defaults = UserDefaults.standard
    private let storage = HTTPCookieStorage.shared

    func restore() {
        guard let data = defaults.data(forKey: AppConstants.StorageKey.cookies),
              let cookieDictionaries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        for properties in cookieDictionaries {
            if let cookie = HTTPCookie(properties: properties) {
                storage.setCookie(cookie)
            }
        }
    }

    func persist() {
        let cookies = storage.cookies ?? []
        let list = cookies.compactMap { $0.properties }
        guard let data = try? JSONSerialization.data(withJSONObject: list, options: []) else {
            return
        }
        defaults.set(data, forKey: AppConstants.StorageKey.cookies)
    }

    func clear() {
        storage.cookies?.forEach(storage.deleteCookie)
        defaults.removeObject(forKey: AppConstants.StorageKey.cookies)
    }
}
