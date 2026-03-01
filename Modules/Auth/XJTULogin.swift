import Foundation
import CommonCrypto
import OSLog

class XJTULogin {
    let loginURL: String
    let client: HTTPClient
    let useWebVPN: Bool

    private(set) var fpVisitorId: String
    private(set) var hasLogin = false
    private(set) var mfaContext: MFAContext?
    private(set) var lastResponseBody = ""

    private var isInitialized = false
    private var postURL = ""
    private var executionInput = ""
    private var mfaEnabled = true
    private var failCount = 0
    private var rsaPublicKey: String?

    private var storedUsername: String?
    private var storedEncryptedPassword: String?
    private var rawPassword: String?
    private var storedCaptcha = ""
    private var chooseAccountBody: String?
    private let logger = Logger(subsystem: "com.xjtu.toolbox.ios", category: "XJTULogin")

    init(
        loginURL: String,
        client: HTTPClient = .shared,
        visitorID: String? = nil,
        cachedRsaPublicKey: String? = nil,
        useWebVPN: Bool = false
    ) {
        self.loginURL = loginURL
        self.client = client
        self.useWebVPN = useWebVPN
        self.fpVisitorId = visitorID ?? Self.generateVisitorID()
        self.rsaPublicKey = cachedRsaPublicKey
    }

    func getRsaPublicKey() -> String? {
        rsaPublicKey
    }

    func login(
        username: String? = nil,
        password: String? = nil,
        captcha: String = "",
        accountType: AccountType = .postgraduate,
        trustAgent: Bool = true
    ) async throws -> LoginResult {
        try await ensureInitialized()
        logger.info("login start loginURL=\(self.loginURL, privacy: .public) hasLogin=\(self.hasLogin, privacy: .public)")
#if DEBUG
        print("[AUTH] login start url=\(loginURL) hasLogin=\(hasLogin)")
#endif

        if chooseAccountBody != nil {
            return try await finishAccountChoice(accountType: accountType, trustAgent: trustAgent)
        }

        if let username, let password {
            storedUsername = username
            rawPassword = password
            storedEncryptedPassword = try await encryptPassword(password)
            storedCaptcha = captcha
        }

        guard let username = storedUsername,
              let encryptedPassword = storedEncryptedPassword else {
            return LoginResult(state: .fail, message: "请输入账号与密码")
        }

        if hasLogin {
            logger.info("login skip because SSO session is already valid")
            return LoginResult(state: .success, message: "SSO 自动认证成功")
        }

        if shouldShowCaptcha, storedCaptcha.isEmpty {
            return LoginResult(state: .requireCaptcha, message: "需要验证码")
        }

        if mfaEnabled, mfaContext == nil {
            logger.info("login mfa detect start")
            let detectResponse = try await client.post(
                "https://login.xjtu.edu.cn/cas/mfa/detect",
                headers: ["Referer": postURL],
                form: [
                    "username": username,
                    "password": encryptedPassword,
                    "fpVisitorId": fpVisitorId
                ]
            )
            if let object = try? jsonObject(from: detectResponse.data),
               let data = object["data"] as? [String: Any],
               let state = data["state"] as? String,
               let need = data["need"] as? Bool {
                mfaContext = MFAContext(state: state, required: need)
                logger.info("login mfa detect done required=\(need, privacy: .public)")
                if need {
                    return LoginResult(state: .requireMFA, mfaContext: mfaContext)
                }
            }
        }

        let mfaState = mfaContext?.state ?? ""
        let trustAgentValue = (mfaContext?.required == true && trustAgent) ? "true" : ""

        let response = try await client.post(
            postURL,
            form: [
                "username": username,
                "password": encryptedPassword,
                "execution": executionInput,
                "_eventId": "submit",
                "submit1": "Login1",
                "fpVisitorId": fpVisitorId,
                "captcha": storedCaptcha,
                "currentMenu": "1",
                "failN": String(failCount),
                "mfaState": mfaState,
                "geolocation": "",
                "trustAgent": trustAgentValue
            ]
        )

        let body = response.bodyString
        lastResponseBody = body
        logger.info("login post done status=\(response.http.statusCode, privacy: .public) finalURL=\(response.finalURL.absoluteString, privacy: .public)")
#if DEBUG
        print("[AUTH] login post status=\(response.http.statusCode) final=\(response.finalURL.absoluteString)")
#endif

        if response.http.statusCode == 401 {
            failCount += 1
            logger.error("login failed: status=401")
            return LoginResult(state: .fail, message: "用户名或密码错误")
        }

        if let message = extractAlertMessage(from: body) {
            failCount += 1
            logger.error("login failed: alert=\(message, privacy: .public)")
            return LoginResult(state: .fail, message: message)
        }

        failCount = 0
        hasLogin = true

        let choices = extractAccountChoices(from: body)
        if !choices.isEmpty {
            chooseAccountBody = body
            hasLogin = false
            return LoginResult(state: .requireAccountChoice, accountChoices: choices)
        }

        try await postLogin(finalURL: response.finalURL, body: body)
        logger.info("login success loginURL=\(self.loginURL, privacy: .public)")
        return LoginResult(state: .success)
    }

    func casAuthenticate(serviceURL: String) async throws -> (body: String, finalURL: URL)? {
        guard let username = storedUsername,
              let encryptedPassword = storedEncryptedPassword else {
            return nil
        }

        let service = serviceURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? serviceURL
        let casURL = "https://login.xjtu.edu.cn/cas/login?service=\(service)"

        let first = try await client.get(casURL)
        let firstBody = first.bodyString
        let execution = extractExecutionValue(from: firstBody)

        if execution.isEmpty {
            return (firstBody, first.finalURL)
        }

        let second = try await client.post(
            first.finalURL.absoluteString,
            form: [
                "username": username,
                "password": encryptedPassword,
                "execution": execution,
                "_eventId": "submit",
                "submit1": "Login1",
                "fpVisitorId": fpVisitorId,
                "currentMenu": "1",
                "failN": "0",
                "mfaState": "",
                "geolocation": ""
            ]
        )

        return (second.bodyString, second.finalURL)
    }

    func fetchCaptchaImage() async throws -> Data {
        let response = try await client.get("https://login.xjtu.edu.cn/cas/captcha.jpg")
        return response.data
    }

    var shouldShowCaptcha: Bool {
        failCount >= 3
    }

    func encryptPassword(_ password: String) async throws -> String {
        if rsaPublicKey == nil {
            let response = try await client.get(
                AppConstants.URLS.casPublicKey,
                headers: ["Referer": postURL]
            )
            rsaPublicKey = response.bodyString
        }

        guard let cachedKey = rsaPublicKey else {
            throw HTTPError.invalidResponse
        }

        do {
            return try RSAEncryptor.encryptPassword(password, withPEM: cachedKey)
        } catch {
            // Android parity: if cached key is stale/corrupted, fetch once and retry.
            logger.error("encryptPassword failed with cached key, refreshing key")
            let response = try await client.get(
                AppConstants.URLS.casPublicKey,
                headers: ["Referer": postURL]
            )
            let freshKey = response.bodyString
            rsaPublicKey = freshKey
            return try RSAEncryptor.encryptPassword(password, withPEM: freshKey)
        }
    }

    func postLogin(finalURL: URL, body: String) async throws {
        // Subclasses override when token extraction is needed.
    }

    private func finishAccountChoice(
        accountType: AccountType,
        trustAgent: Bool
    ) async throws -> LoginResult {
        guard let body = chooseAccountBody else {
            return LoginResult(state: .fail, message: "无需账号选择")
        }

        let choices = extractAccountChoices(from: body)
        let selected: AccountChoice?
        switch accountType {
        case .undergraduate:
            selected = choices.first(where: { $0.name.contains("本科") || $0.label.contains("本科") })
        case .postgraduate:
            selected = choices.first(where: { $0.name.contains("研究") || $0.label.contains("研究") })
        }

        guard let choice = selected else {
            return LoginResult(state: .fail, message: "无法匹配账号类型")
        }

        let execution = extractExecutionValue(from: body)
        let trustAgentValue = (mfaContext?.required == true && trustAgent) ? "true" : ""

        let response = try await client.post(
            "https://login.xjtu.edu.cn/cas/login",
            form: [
                "execution": execution,
                "_eventId": "submit",
                "geolocation": "",
                "fpVisitorId": fpVisitorId,
                "trustAgent": trustAgentValue,
                "username": choice.label,
                "useDefault": "false"
            ]
        )

        let responseBody = response.bodyString
        lastResponseBody = responseBody
        chooseAccountBody = nil
        hasLogin = true
        try await postLogin(finalURL: response.finalURL, body: responseBody)
        return LoginResult(state: .success)
    }

    private func ensureInitialized() async throws {
        if isInitialized {
            return
        }

        let response = try await client.get(loginURL, useWebVPN: useWebVPN)
        let body = response.bodyString
        postURL = response.finalURL.absoluteString
        executionInput = extractExecutionValue(from: body)

        logger.info("ensureInitialized finalURL=\(response.finalURL.absoluteString, privacy: .public) executionEmpty=\(self.executionInput.isEmpty, privacy: .public)")
#if DEBUG
        print("[AUTH] init final=\(response.finalURL.absoluteString) executionEmpty=\(self.executionInput.isEmpty)")
#endif

        if executionInput.isEmpty {
            // Existing SSO cookies can skip the form page.
            hasLogin = true
            mfaEnabled = false
            lastResponseBody = body
            try await postLogin(finalURL: response.finalURL, body: body)
        } else {
            mfaEnabled = extractMfaEnabled(from: body)
        }
        isInitialized = true
    }

    private func extractExecutionValue(from html: String) -> String {
        html.firstMatch(pattern: #"name=["']execution["'][^>]*value=["']([^"']+)["']"#, options: [.caseInsensitive]) ?? ""
    }

    private func extractMfaEnabled(from html: String) -> Bool {
        guard let value = html.firstMatch(
            pattern: #"["']?mfaEnabled["']?\s*[:=]\s*["']?(true|false)["']?"#,
            options: [.caseInsensitive]
        ) else {
            return true
        }
        return value.lowercased() == "true"
    }

    private func extractAlertMessage(from html: String) -> String? {
        if let title = html.firstMatch(
            pattern: #"<el-alert[^>]*title=["']([^"']+)["']"#,
            options: [.caseInsensitive]
        ), !title.isEmpty {
            return title
        }
        if let error = html.firstMatch(
            pattern: #"(?:alert-danger|errors|errorMessage)[^>]*>([^<]+)<"#,
            options: [.caseInsensitive]
        ), !error.isEmpty {
            return error
        }
        return nil
    }

    private func extractAccountChoices(from html: String) -> [AccountChoice] {
        var result: [AccountChoice] = []

        let wrapRegex = try? NSRegularExpression(
            pattern: #"<div[^>]*class=["'][^"']*account-wrap[^"']*["'][\s\S]*?<div[^>]*class=["'][^"']*name[^"']*["'][^>]*>([^<]*)</div>[\s\S]*?<el-radio[^>]*label=["']([^"']+)["']"#,
            options: [.caseInsensitive]
        )

        if let regex = wrapRegex {
            let nsRange = NSRange(html.startIndex..., in: html)
            for match in regex.matches(in: html, range: nsRange) {
                guard match.numberOfRanges > 2,
                      let nameRange = Range(match.range(at: 1), in: html),
                      let labelRange = Range(match.range(at: 2), in: html) else {
                    continue
                }
                let name = String(html[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let label = String(html[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !label.isEmpty {
                    result.append(AccountChoice(name: name.isEmpty ? label : name, label: label))
                }
            }
        }

        if !result.isEmpty {
            return result
        }

        // Fallback for old CAS pages.
        let labels = html.allMatches(
            pattern: #"<input[^>]*name=["']username["'][^>]*value=["']([^"']+)["']"#,
            options: [.caseInsensitive]
        )
        result = labels.map { AccountChoice(name: $0, label: $0) }
        return result
    }

    private func jsonObject(from data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        return dict
    }

    private static func generateVisitorID() -> String {
        let source = "\(UUID().uuidString)|\(ProcessInfo.processInfo.operatingSystemVersionString)"
        let digest = source.data(using: .utf8)?.sha256Hex ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return String(digest.prefix(32))
    }
}

private extension Data {
    var sha256Hex: String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
