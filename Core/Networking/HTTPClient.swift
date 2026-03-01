import Foundation

struct HTTPResponse {
    let data: Data
    let http: HTTPURLResponse
    let finalURL: URL

    var bodyString: String {
        String(data: data, encoding: .utf8) ?? ""
    }
}

actor HTTPClient {
    static let shared = HTTPClient()

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    func get(
        _ rawURL: String,
        headers: [String: String] = [:],
        useWebVPN: Bool = false
    ) async throws -> HTTPResponse {
        guard let url = URL(string: rawURL) else {
            throw HTTPError.invalidURL
        }
        var request = URLRequest(url: processedURL(for: url, useWebVPN: useWebVPN))
        request.httpMethod = "GET"
        applyCommonHeaders(to: &request, custom: headers)
        return try await execute(request)
    }

    func post(
        _ rawURL: String,
        headers: [String: String] = [:],
        form: [String: String]? = nil,
        json: Any? = nil,
        body: Data? = nil,
        contentType: String? = nil,
        useWebVPN: Bool = false
    ) async throws -> HTTPResponse {
        guard let url = URL(string: rawURL) else {
            throw HTTPError.invalidURL
        }
        var request = URLRequest(url: processedURL(for: url, useWebVPN: useWebVPN))
        request.httpMethod = "POST"

        if let form {
            let encoded = form.map { key, value in
                let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(escapedKey)=\(escapedValue)"
            }.joined(separator: "&")
            request.httpBody = encoded.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        } else if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if let body {
            request.httpBody = body
            if let contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        } else {
            request.httpBody = Data()
        }

        applyCommonHeaders(to: &request, custom: headers)
        return try await execute(request)
    }

    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              let finalURL = http.url else {
            throw HTTPError.invalidResponse
        }
        await CookiePersistence.shared.persist()
        return HTTPResponse(data: data, http: http, finalURL: finalURL)
    }

    func currentCookies(for host: String) -> [HTTPCookie] {
        guard let url = URL(string: "https://\(host)") else {
            return []
        }
        return HTTPCookieStorage.shared.cookies(for: url) ?? []
    }

    private func processedURL(for url: URL, useWebVPN: Bool) -> URL {
        guard useWebVPN,
              url.host != "login.xjtu.edu.cn",
              !WebVPN.isWebVPNURL(url) else {
            return url
        }
        return WebVPN.vpnURL(for: url)
    }

    private func applyCommonHeaders(to request: inout URLRequest, custom: [String: String]) {
        request.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        for (k, v) in custom {
            request.setValue(v, forHTTPHeaderField: k)
        }
    }
}
