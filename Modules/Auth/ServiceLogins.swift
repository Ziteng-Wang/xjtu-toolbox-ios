import Foundation

final class AttendanceLogin: XJTULogin {
    private(set) var authToken: String?
    private let webVPNMode: Bool

    init(
        client: HTTPClient = .shared,
        visitorID: String? = nil,
        useWebVPN: Bool = false
    ) {
        webVPNMode = useWebVPN
        super.init(
            loginURL: useWebVPN ? AppConstants.URLS.attendanceWebVPNURL : AppConstants.URLS.attendanceURL,
            client: client,
            visitorID: visitorID,
            useWebVPN: useWebVPN
        )
    }

    override func postLogin(finalURL: URL, body: String) async throws {
        if let token = finalURL.queryItemValue("token"), !token.isEmpty {
            authToken = token
            return
        }

        let retryURL = webVPNMode ? AppConstants.URLS.attendanceWebVPNURL : AppConstants.URLS.attendanceURL
        let retry = try await client.get(retryURL, useWebVPN: webVPNMode)
        if let token = retry.finalURL.queryItemValue("token"), !token.isEmpty {
            authToken = token
            return
        }
        throw HTTPError.authenticationRequired
    }

    func reAuthenticate() async -> Bool {
        do {
            let retryURL = webVPNMode ? AppConstants.URLS.attendanceWebVPNURL : AppConstants.URLS.attendanceURL
            let retry = try await client.get(retryURL, useWebVPN: webVPNMode)
            authToken = retry.finalURL.queryItemValue("token")
            return !(authToken ?? "").isEmpty
        } catch {
            return false
        }
    }

    func executeWithReAuth(
        url: String,
        method: String = "GET",
        body: Data? = nil,
        contentType: String? = nil
    ) async throws -> HTTPResponse {
        let token = authToken ?? ""
        let headers = ["Synjones-Auth": "bearer \(token)"]
        let response: HTTPResponse
        switch method {
        case "POST":
            response = try await client.post(url, headers: headers, body: body, contentType: contentType, useWebVPN: webVPNMode)
        default:
            response = try await client.get(url, headers: headers, useWebVPN: webVPNMode)
        }

        if [401, 403].contains(response.http.statusCode), await reAuthenticate() {
            let retryToken = authToken ?? ""
            let retryHeaders = ["Synjones-Auth": "bearer \(retryToken)"]
            switch method {
            case "POST":
                return try await client.post(url, headers: retryHeaders, body: body, contentType: contentType, useWebVPN: webVPNMode)
            default:
                return try await client.get(url, headers: retryHeaders, useWebVPN: webVPNMode)
            }
        }
        return response
    }
}

final class JwxtLogin: XJTULogin {
    init(client: HTTPClient = .shared, visitorID: String? = nil, cachedRsaPublicKey: String? = nil) {
        super.init(
            loginURL: AppConstants.URLS.jwxtURL,
            client: client,
            visitorID: visitorID,
            cachedRsaPublicKey: cachedRsaPublicKey
        )
    }
}

final class JwappLogin: XJTULogin {
    private(set) var authToken: String?
    private(set) var tokenObtainedAt: Date?

    init(client: HTTPClient = .shared, visitorID: String? = nil, cachedRsaPublicKey: String? = nil) {
        super.init(
            loginURL: AppConstants.URLS.jwappURL,
            client: client,
            visitorID: visitorID,
            cachedRsaPublicKey: cachedRsaPublicKey
        )
    }

    override func postLogin(finalURL: URL, body: String) async throws {
        guard let token = finalURL.queryItemValue("token"), !token.isEmpty else {
            throw HTTPError.authenticationRequired
        }
        authToken = token
        tokenObtainedAt = Date()
    }

    func isTokenValid(ttl: TimeInterval = 3600) -> Bool {
        guard let token = authToken,
              !token.isEmpty,
              let date = tokenObtainedAt else {
            return false
        }
        return Date().timeIntervalSince(date) < ttl
    }

    func reAuthenticate() async -> Bool {
        do {
            let response = try await client.get(AppConstants.URLS.jwappURL)
            if let token = response.finalURL.queryItemValue("token"), !token.isEmpty {
                authToken = token
                tokenObtainedAt = Date()
                return true
            }
            return false
        } catch {
            return false
        }
    }

    func executeWithReAuth(
        url: String,
        method: String = "GET",
        json: Any? = nil
    ) async throws -> HTTPResponse {
        if !isTokenValid() {
            _ = await reAuthenticate()
        }

        let headers = ["Authorization": authToken ?? ""]
        let response: HTTPResponse
        switch method {
        case "POST":
            response = try await client.post(url, headers: headers, json: json)
        default:
            response = try await client.get(url, headers: headers)
        }

        if [401, 403].contains(response.http.statusCode), await reAuthenticate() {
            let retryHeaders = ["Authorization": authToken ?? ""]
            switch method {
            case "POST":
                return try await client.post(url, headers: retryHeaders, json: json)
            default:
                return try await client.get(url, headers: retryHeaders)
            }
        }
        return response
    }
}

final class YwtbLogin: XJTULogin {
    private(set) var idToken: String?
    private(set) var tokenExpireAt: Date?
    private(set) var tokenObtainedAt: Date?

    init(client: HTTPClient = .shared, visitorID: String? = nil, cachedRsaPublicKey: String? = nil) {
        super.init(
            loginURL: AppConstants.URLS.ywtbURL,
            client: client,
            visitorID: visitorID,
            cachedRsaPublicKey: cachedRsaPublicKey
        )
    }

    override func postLogin(finalURL: URL, body: String) async throws {
        try extractToken(finalURL: finalURL)
    }

    func isTokenValid() -> Bool {
        guard let token = idToken, !token.isEmpty else {
            return false
        }

        if let expireAt = tokenExpireAt {
            return Date().addingTimeInterval(30) < expireAt
        }

        if let obtained = tokenObtainedAt {
            return Date().timeIntervalSince(obtained) < 3600
        }

        return true
    }

    func reAuthenticate() async -> Bool {
        do {
            let response = try await client.get(AppConstants.URLS.ywtbURL)
            try extractToken(finalURL: response.finalURL)
            return true
        } catch {
            return false
        }
    }

    func executeWithReAuth(url: String) async throws -> HTTPResponse {
        if !isTokenValid() {
            _ = await reAuthenticate()
        }

        let headers = [
            "x-id-token": idToken ?? "",
            "x-device-info": "PC",
            "x-terminal-info": "PC",
            "Referer": "https://ywtb.xjtu.edu.cn/main.html"
        ]

        let response = try await client.get(url, headers: headers)
        if [401, 403].contains(response.http.statusCode), await reAuthenticate() {
            let retryHeaders = [
                "x-id-token": idToken ?? "",
                "x-device-info": "PC",
                "x-terminal-info": "PC",
                "Referer": "https://ywtb.xjtu.edu.cn/main.html"
            ]
            return try await client.get(url, headers: retryHeaders)
        }
        return response
    }

    private func extractToken(finalURL: URL) throws {
        guard let ticket = finalURL.queryItemValue("ticket"), !ticket.isEmpty else {
            throw HTTPError.authenticationRequired
        }

        let parts = ticket.split(separator: ".")
        guard parts.count >= 2 else {
            throw HTTPError.authenticationRequired
        }

        var payload = String(parts[1])
        let remainder = payload.count % 4
        if remainder == 2 {
            payload += "=="
        } else if remainder == 3 {
            payload += "="
        }

        guard let payloadData = Data(base64Encoded: payload.base64URLToBase64()),
              let object = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw HTTPError.authenticationRequired
        }

        guard let idToken = object["idToken"] as? String else {
            throw HTTPError.authenticationRequired
        }

        self.idToken = idToken
        tokenObtainedAt = Date()

        if let exp = object["exp"] as? TimeInterval {
            tokenExpireAt = Date(timeIntervalSince1970: exp)
        } else if let exp = object["exp"] as? Int {
            tokenExpireAt = Date(timeIntervalSince1970: TimeInterval(exp))
        } else {
            tokenExpireAt = nil
        }
    }
}

final class LibraryLogin: XJTULogin {
    static let seatBaseURL = "http://rg.lib.xjtu.edu.cn:8086"

    private(set) var seatSystemReady = false
    private(set) var diagnosticInfo = ""

    init(client: HTTPClient = .shared, visitorID: String? = nil, useWebVPN: Bool = false) {
        super.init(
            loginURL: AppConstants.URLS.librarySeatURL,
            client: client,
            visitorID: visitorID,
            useWebVPN: useWebVPN
        )
    }

    override func postLogin(finalURL: URL, body: String) async throws {
        if isSeatPage(body) {
            seatSystemReady = true
            diagnosticInfo = "座位系统已就绪"
            return
        }

        let recovered = try await reAuthenticate()
        if !recovered {
            throw HTTPError.authenticationRequired
        }
    }

    func reAuthenticate() async throws -> Bool {
        let response = try await client.get("\(Self.seatBaseURL)/seat/", useWebVPN: useWebVPN)
        let body = response.bodyString
        if isSeatPage(body) {
            seatSystemReady = true
            diagnosticInfo = "座位系统已就绪"
            return true
        }

        seatSystemReady = false
        diagnosticInfo = "座位系统认证失败，请确认校园网或 VPN"
        return false
    }

    private func isSeatPage(_ body: String) -> Bool {
        body.contains("btn-group") || body.contains("tab-select") || body.contains("seat")
    }
}

final class CampusCardLogin: XJTULogin {
    static let baseURL = "http://card.xjtu.edu.cn"

    private(set) var hallticket: String?
    var cardAccount: String?
    private(set) var systemReady = false

    init(client: HTTPClient = .shared, visitorID: String? = nil, cachedRsaPublicKey: String? = nil) {
        super.init(
            loginURL: AppConstants.URLS.campusCardURL,
            client: client,
            visitorID: visitorID,
            cachedRsaPublicKey: cachedRsaPublicKey
        )
    }

    override func postLogin(finalURL: URL, body: String) async throws {
        extractHallticketFromCookie()
        if hallticket != nil {
            systemReady = true
            return
        }

        let fallback = try await client.get("\(Self.baseURL)/Page/Page")
        extractHallticketFromCookie()
        if hallticket == nil, fallback.bodyString.count > 500 {
            systemReady = true
        }
    }

    func reAuthenticate() async -> Bool {
        do {
            let _ = try await client.get(AppConstants.URLS.campusCardURL)
            extractHallticketFromCookie()
            if hallticket != nil {
                systemReady = true
                return true
            }
            let _ = try await client.get("\(Self.baseURL)/Page/Page")
            extractHallticketFromCookie()
            systemReady = hallticket != nil
            return systemReady
        } catch {
            return false
        }
    }

    private func extractHallticketFromCookie() {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let cardCookies = cookies.filter { $0.domain.contains("card.xjtu.edu.cn") }
        hallticket = cardCookies.first(where: { $0.name == "hallticket" })?.value
        if hallticket != nil {
            systemReady = true
        }
    }
}

final class GmisLogin: XJTULogin {
    init(client: HTTPClient = .shared, visitorID: String? = nil) {
        super.init(
            loginURL: AppConstants.URLS.gmisURL,
            client: client,
            visitorID: visitorID
        )
    }
}

final class GsteLogin: XJTULogin {
    init(client: HTTPClient = .shared, visitorID: String? = nil) {
        super.init(
            loginURL: AppConstants.URLS.gsteURL,
            client: client,
            visitorID: visitorID
        )
    }
}

private extension URL {
    func queryItemValue(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == name })?.value
    }
}

private extension String {
    func base64URLToBase64() -> String {
        replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
    }
}
