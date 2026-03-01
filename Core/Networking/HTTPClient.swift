import Foundation
import OSLog

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
    private let logger = Logger(subsystem: "com.xjtu.toolbox.ios", category: "HTTPClient")

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
            // Align with Android OkHttp FormBody: special chars in encrypted password
            // (e.g. '+', '=', '/') must be encoded in x-www-form-urlencoded body.
            let encoded = form
                .sorted(by: { $0.key < $1.key })
                .map { key, value in
                    "\(Self.formURLEncode(key))=\(Self.formURLEncode(value))"
                }
                .joined(separator: "&")
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
        if let method = request.httpMethod, let url = request.url?.absoluteString {
            logger.info("request \(method, privacy: .public) \(url, privacy: .public)")
#if DEBUG
            print("[HTTP] request \(method) \(url)")
#endif
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              let finalURL = http.url else {
            throw HTTPError.invalidResponse
        }

        logger.info("response status=\(http.statusCode, privacy: .public) final=\(finalURL.absoluteString, privacy: .public)")
#if DEBUG
        print("[HTTP] response status=\(http.statusCode) final=\(finalURL.absoluteString)")
#endif
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

    private static func formURLEncode(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._* "))
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? raw
        return encoded.replacingOccurrences(of: " ", with: "+")
    }
}
