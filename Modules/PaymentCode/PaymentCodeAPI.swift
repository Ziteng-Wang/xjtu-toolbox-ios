import Foundation

private actor PaymentCodeTokenCache {
    static let shared = PaymentCodeTokenCache()

    private var token: String?
    private var updatedAt: Date?

    func load(validFor interval: TimeInterval) -> String? {
        guard let token, let updatedAt else {
            return nil
        }
        guard Date().timeIntervalSince(updatedAt) <= interval else {
            return nil
        }
        return token
    }

    func save(_ token: String) {
        self.token = token
        self.updatedAt = Date()
    }

    func clear() {
        token = nil
        updatedAt = nil
    }
}

final class PaymentCodeAPI {
    private let client: HTTPClient
    private var jwtToken: String?

    private static let baseURL = "https://pay.xjtu.edu.cn"
    private static let casEntry = "\(baseURL)/ThirdWeb/CasQrcode"
    private static let jwtTTL: TimeInterval = 30 * 60
    private static let jwtPattern = #"sessionStorage\.Authorization\s*=\s*'(eyJ[^']+)'"#

    init(client: HTTPClient = .shared) {
        self.client = client
    }

    func authenticate(force: Bool = false) async throws {
        if !force,
           let cached = await PaymentCodeTokenCache.shared.load(validFor: Self.jwtTTL) {
            jwtToken = cached
            return
        }

        let response = try await client.get(Self.casEntry)
        guard response.http.statusCode == 200,
              response.finalURL.host?.contains("pay.xjtu.edu.cn") == true else {
            throw HTTPError.authenticationRequired
        }

        guard let token = response.bodyString.firstMatch(pattern: Self.jwtPattern, options: [.caseInsensitive]),
              !token.isEmpty else {
            throw HTTPError.invalidResponse
        }

        jwtToken = token
        await PaymentCodeTokenCache.shared.save(token)
    }

    func getBarCode() async throws -> String {
        if jwtToken == nil {
            try await authenticate()
        }

        do {
            return try await fetchBarCode()
        } catch {
            try await authenticate(force: true)
            return try await fetchBarCode()
        }
    }

    static func clearCachedJWT() async {
        await PaymentCodeTokenCache.shared.clear()
    }

    private func fetchBarCode() async throws -> String {
        guard let token = jwtToken, !token.isEmpty else {
            throw HTTPError.authenticationRequired
        }

        let response = try await client.post(
            "\(Self.baseURL)/ThirdWeb/GetBarCode",
            headers: [
                "Accept": "application/json, text/javascript, */*; q=0.01",
                "X-Requested-With": "XMLHttpRequest",
                "Authorization": token,
                "Referer": Self.casEntry
            ],
            form: ["acctype": "000"]
        )

        guard response.http.statusCode == 200 else {
            throw HTTPError.serverError(status: response.http.statusCode, message: "获取付款码失败")
        }

        guard let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            throw HTTPError.invalidResponse
        }

        let succeed = object.bool("IsSucceed")
        guard succeed else {
            let message = object.string("Msg", default: "获取付款码失败")
            throw HTTPError.serverError(status: 200, message: message)
        }

        let code = (object["Obj"] as? [Any])?.first as? String ?? ""
        guard !code.isEmpty else {
            throw HTTPError.emptyBody
        }
        return code
    }
}
