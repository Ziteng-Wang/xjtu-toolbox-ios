import Foundation

actor CookiePersistence {
    static let shared = CookiePersistence()

    private let defaults = UserDefaults.standard
    private let storage = HTTPCookieStorage.shared
    private let expiresKey = HTTPCookiePropertyKey.expires.rawValue
    private let commentURLKey = HTTPCookiePropertyKey.commentURL.rawValue

    func restore() {
        guard let data = defaults.data(forKey: AppConstants.StorageKey.cookies),
              let cookieDictionaries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        for serialized in cookieDictionaries {
            var properties: [HTTPCookiePropertyKey: Any] = [:]
            for (rawKey, rawValue) in serialized {
                let key = HTTPCookiePropertyKey(rawValue: rawKey)
                switch rawKey {
                case expiresKey:
                    let date: Date?
                    if let interval = rawValue as? TimeInterval {
                        date = Date(timeIntervalSince1970: interval)
                    } else if let intervalString = rawValue as? String,
                              let interval = TimeInterval(intervalString) {
                        date = Date(timeIntervalSince1970: interval)
                    } else {
                        date = nil
                    }
                    if let date {
                        properties[key] = date
                    }
                case commentURLKey:
                    if let string = rawValue as? String, let url = URL(string: string) {
                        properties[key] = url
                    }
                default:
                    properties[key] = rawValue
                }
            }

            if let cookie = HTTPCookie(properties: properties) {
                storage.setCookie(cookie)
            }
        }
    }

    func persist() {
        let cookies = storage.cookies ?? []
        let list: [[String: Any]] = cookies.compactMap { cookie in
            guard let properties = cookie.properties else {
                return nil
            }

            var serialized: [String: Any] = [:]
            for (key, value) in properties {
                switch value {
                case let date as Date:
                    serialized[key.rawValue] = date.timeIntervalSince1970
                case let url as URL:
                    serialized[key.rawValue] = url.absoluteString
                case let number as NSNumber:
                    serialized[key.rawValue] = number
                case let string as String:
                    serialized[key.rawValue] = string
                default:
                    continue
                }
            }
            return serialized
        }

        guard JSONSerialization.isValidJSONObject(list) else {
            return
        }
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
