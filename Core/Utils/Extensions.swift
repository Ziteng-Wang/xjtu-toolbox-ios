import Foundation

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String, default defaultValue: String = "") -> String {
        if let value = self[key] as? String {
            return value
        }
        if let value = self[key] {
            return String(describing: value)
        }
        return defaultValue
    }

    func int(_ key: String, default defaultValue: Int = 0) -> Int {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? Double {
            return Int(value)
        }
        if let value = self[key] as? String {
            return Int(value) ?? defaultValue
        }
        return defaultValue
    }

    func double(_ key: String, default defaultValue: Double = 0) -> Double {
        if let value = self[key] as? Double {
            return value
        }
        if let value = self[key] as? Int {
            return Double(value)
        }
        if let value = self[key] as? String {
            return Double(value) ?? defaultValue
        }
        return defaultValue
    }

    func bool(_ key: String, default defaultValue: Bool = false) -> Bool {
        if let value = self[key] as? Bool {
            return value
        }
        if let value = self[key] as? Int {
            return value != 0
        }
        if let value = self[key] as? String {
            switch value.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return defaultValue
            }
        }
        return defaultValue
    }
}

extension DateFormatter {
    static let ymd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    static let ymdhm: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()
}

extension String {
    func firstMatch(pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range) else {
            return nil
        }
        guard match.numberOfRanges > 1,
              let resultRange = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return String(self[resultRange])
    }

    func allMatches(pattern: String, options: NSRegularExpression.Options = []) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        let range = NSRange(startIndex..., in: self)
        return regex.matches(in: self, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let resultRange = Range(match.range(at: 1), in: self) else {
                return nil
            }
            return String(self[resultRange])
        }
    }

    var removingInvisibleCharacters: String {
        replacingOccurrences(of: "[^a-zA-Z0-9+\\-\\u4e00-\\u9fff]", with: "", options: .regularExpression)
    }
}

extension URL {
    func appendingQuery(_ items: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: items)
        components.queryItems = queryItems
        return components.url ?? self
    }
}
