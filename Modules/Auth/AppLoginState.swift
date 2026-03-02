import Foundation
import OSLog

@MainActor
final class AppLoginState: ObservableObject {
    @Published var eulaAccepted = false
    @Published var activeUsername: String = ""
    @Published var isOnCampus: Bool?
    @Published var ywtbUserInfo: UserInfo?
    @Published var nsaProfile: NsaStudentProfile?
    @Published var nsaPhotoData: Data?
    @Published var nsaLoading = false
    @Published var nsaError: String?
    @Published var lastLoginError: String?

    @Published var attendanceLogin: AttendanceLogin?
    @Published var jwxtLogin: JwxtLogin?
    @Published var jwappLogin: JwappLogin?
    @Published var ywtbLogin: YwtbLogin?
    @Published var libraryLogin: LibraryLogin?
    @Published var campusCardLogin: CampusCardLogin?
    @Published var gmisLogin: GmisLogin?
    @Published var gsteLogin: GsteLogin?

    private let client: HTTPClient
    private let credentialStore: CredentialStore
    private let logger = Logger(subsystem: "com.xjtu.toolbox.ios", category: "AppLoginState")

    private var webVPNReady = false
    private var cachedVisitorID: String?
    private var cachedRsaPublicKey: String?
    private var loginTasks: [LoginType: Task<XJTULogin?, Never>] = [:]

    private(set) var savedUsername: String = ""
    private(set) var savedPassword: String = ""

    init(
        client: HTTPClient = .shared,
        credentialStore: CredentialStore = .shared
    ) {
        self.client = client
        self.credentialStore = credentialStore
    }

    var hasCredentials: Bool {
        !savedUsername.isEmpty && !savedPassword.isEmpty
    }

    var isLoggedIn: Bool {
        !activeUsername.isEmpty
    }

    func bootstrap() async {
        await CookiePersistence.shared.restore()
        eulaAccepted = await credentialStore.isEulaAccepted()

        if let credential = await credentialStore.loadCredential() {
            savedUsername = credential.username
            savedPassword = credential.password
            cachedVisitorID = await credentialStore.loadVisitorID()
            cachedRsaPublicKey = await credentialStore.loadRSAPublicKey()
            nsaProfile = await credentialStore.loadNsaProfile()
            nsaPhotoData = await credentialStore.loadNsaPhoto()
        }

        guard hasCredentials else { return }

        // Warm up core systems; individual screens still lazy-login when entered.
        _ = await autoLogin(type: .jwxt)
        _ = await autoLogin(type: .jwapp)
        _ = await autoLogin(type: .ywtb)
    }

    func acceptEula() async {
        await credentialStore.acceptEula()
        eulaAccepted = true
    }

    func saveCredentials(username: String, password: String) async {
        savedUsername = username
        savedPassword = password
        await credentialStore.saveCredential(username: username, password: password)
    }

    func persistRuntimeCache() async {
        if let cachedVisitorID {
            await credentialStore.saveVisitorID(cachedVisitorID)
        }
        if let cachedRsaPublicKey {
            await credentialStore.saveRSAPublicKey(cachedRsaPublicKey)
        }
        await CookiePersistence.shared.persist()
    }

    func logout() async {
        activeUsername = ""
        ywtbUserInfo = nil
        nsaProfile = nil
        nsaPhotoData = nil
        nsaError = nil
        attendanceLogin = nil
        jwxtLogin = nil
        jwappLogin = nil
        ywtbLogin = nil
        libraryLogin = nil
        campusCardLogin = nil
        gmisLogin = nil
        gsteLogin = nil
        isOnCampus = nil
        webVPNReady = false
        lastLoginError = nil
        loginTasks.removeAll()

        savedUsername = ""
        savedPassword = ""

        await credentialStore.clearAll()
        await CookiePersistence.shared.clear()
        await PaymentCodeAPI.clearCachedJWT()
    }

    func autoLogin(type: LoginType) async -> XJTULogin? {
        if let task = loginTasks[type] {
            logger.info("autoLogin join in-flight task type=\(type.rawValue, privacy: .public)")
            return await task.value
        }

        let startedAt = Date()
        let task = Task<XJTULogin?, Never> { @MainActor [weak self] in
            guard let self else { return nil }
            return await self.performAutoLogin(type: type)
        }
        loginTasks[type] = task
        let result = await task.value
        loginTasks[type] = nil

        if type == .jwapp {
            let elapsedMS = Int(Date().timeIntervalSince(startedAt) * 1000)
            logger.info("autoLogin finished type=jwapp elapsedMs=\(elapsedMS, privacy: .public)")
#if DEBUG
            print("[AUTH] autoLogin finished type=jwapp elapsedMs=\(elapsedMS)")
#endif
        }
        return result
    }

    private func performAutoLogin(type: LoginType) async -> XJTULogin? {
        logger.info("autoLogin start type=\(type.rawValue, privacy: .public) hasCredentials=\(self.hasCredentials, privacy: .public)")
#if DEBUG
        print("[AUTH] autoLogin start type=\(type.rawValue) hasCredentials=\(hasCredentials)")
#endif

        if let cached = cachedLogin(for: type) {
            if type == .library, let library = cached as? LibraryLogin {
                if library.seatSystemReady {
                    logger.info("autoLogin use cached library session")
                    return library
                }
                if (try? await library.reAuthenticate()) == true {
                    logger.info("autoLogin library reAuthenticate success")
                    return library
                }
                lastLoginError = library.diagnosticInfo.isEmpty ? "图书馆认证状态失效" : library.diagnosticInfo
                libraryLogin = nil
                logger.error("autoLogin library cached session invalid: \(self.lastLoginError ?? "", privacy: .public)")
            } else {
                logger.info("autoLogin use cached type=\(type.rawValue, privacy: .public)")
                return cached
            }
        }

        guard hasCredentials else {
            lastLoginError = "请先输入账号和密码"
            return nil
        }

        let needsInternalNetwork = type == .attendance || type == .library
        var isOffCampusWithoutVPN = false
        if needsInternalNetwork {
            if isOnCampus == nil {
                isOnCampus = await detectCampusNetwork()
            }
            if isOnCampus == false, !webVPNReady {
                webVPNReady = await loginWebVPN()
            }
            isOffCampusWithoutVPN = isOnCampus == false && !webVPNReady
        }

        let useWebVPN = needsInternalNetwork && isOnCampus == false && webVPNReady

        let login = makeLogin(type: type, useWebVPN: useWebVPN)

        do {
            var result = try await login.login(username: savedUsername, password: savedPassword)
            if result.state == .requireAccountChoice {
                result = try await login.login(accountType: .undergraduate)
            }
            logger.info("autoLogin result type=\(type.rawValue, privacy: .public) state=\(String(describing: result.state), privacy: .public)")
#if DEBUG
            print("[AUTH] autoLogin result type=\(type.rawValue) state=\(result.state)")
#endif

            guard result.state == .success else {
                var message = loginFailureMessage(from: result)
                if isOffCampusWithoutVPN {
                    message += "（当前疑似校外网络，且 WebVPN 未连接成功）"
                }
                lastLoginError = message
                logger.error("autoLogin failed type=\(type.rawValue, privacy: .public) message=\(message, privacy: .public)")
                return nil
            }

            lastLoginError = nil
            cache(login: login, username: savedUsername)
            cachedVisitorID = login.fpVisitorId
            if let rsa = login.getRsaPublicKey() {
                cachedRsaPublicKey = rsa
            }
            await persistRuntimeCache()

            if type == .ywtb,
               let ywtbLogin = ywtbLogin {
                let api = YWTBAPI(login: ywtbLogin)
                ywtbUserInfo = try? await api.getUserInfo()
            }

            logger.info("autoLogin success type=\(type.rawValue, privacy: .public)")
            return login
        } catch {
            var message = readableLoginError(error)
            if isOffCampusWithoutVPN {
                message += "（当前疑似校外网络，且 WebVPN 未连接成功）"
            }
            lastLoginError = message
            logger.error("autoLogin error type=\(type.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)")
#if DEBUG
            print("[AUTH] autoLogin error type=\(type.rawValue) error=\(error)")
#endif
            return nil
        }
    }

    func ensureLogin(type: LoginType) async -> Bool {
        await autoLogin(type: type) != nil
    }

    func loadNsaProfile(force: Bool = false) async {
        if !force, nsaProfile != nil {
            return
        }

        nsaLoading = true
        nsaError = nil
        defer { nsaLoading = false }

        guard await ensureLogin(type: .jwxt),
              let login = jwxtLogin else {
            nsaError = "未登录教务系统"
            return
        }

        do {
            let api = NsaAPI(login: login)
            let profile = try await api.getProfile()
            let photo = try await api.getStudentPhoto(studentID: profile.studentId)

            nsaProfile = profile
            nsaPhotoData = photo
            nsaError = nil

            await credentialStore.saveNsaProfile(profile)
            if let photo {
                await credentialStore.saveNsaPhoto(photo)
            }
        } catch {
            nsaError = error.localizedDescription
        }
    }

    private func makeLogin(type: LoginType, useWebVPN: Bool) -> XJTULogin {
        switch type {
        case .attendance:
            return AttendanceLogin(client: client, visitorID: cachedVisitorID, useWebVPN: useWebVPN)
        case .jwxt:
            return JwxtLogin(client: client, visitorID: cachedVisitorID, cachedRsaPublicKey: cachedRsaPublicKey)
        case .jwapp:
            return JwappLogin(client: client, visitorID: cachedVisitorID, cachedRsaPublicKey: cachedRsaPublicKey)
        case .ywtb:
            return YwtbLogin(client: client, visitorID: cachedVisitorID, cachedRsaPublicKey: cachedRsaPublicKey)
        case .library:
            return LibraryLogin(client: client, visitorID: cachedVisitorID, useWebVPN: useWebVPN)
        case .campusCard:
            return CampusCardLogin(client: client, visitorID: cachedVisitorID, cachedRsaPublicKey: cachedRsaPublicKey)
        case .gmis:
            return GmisLogin(client: client, visitorID: cachedVisitorID)
        case .gste:
            return GsteLogin(client: client, visitorID: cachedVisitorID)
        }
    }

    private func cachedLogin(for type: LoginType) -> XJTULogin? {
        switch type {
        case .attendance:
            return attendanceLogin
        case .jwxt:
            return jwxtLogin
        case .jwapp:
            return jwappLogin
        case .ywtb:
            return ywtbLogin
        case .library:
            return libraryLogin
        case .campusCard:
            return campusCardLogin
        case .gmis:
            return gmisLogin
        case .gste:
            return gsteLogin
        }
    }

    private func cache(login: XJTULogin, username: String) {
        activeUsername = username

        switch login {
        case let value as AttendanceLogin:
            attendanceLogin = value
        case let value as JwxtLogin:
            jwxtLogin = value
        case let value as JwappLogin:
            jwappLogin = value
        case let value as YwtbLogin:
            ywtbLogin = value
        case let value as LibraryLogin:
            libraryLogin = value
        case let value as CampusCardLogin:
            campusCardLogin = value
        case let value as GmisLogin:
            gmisLogin = value
        case let value as GsteLogin:
            gsteLogin = value
        default:
            break
        }
    }

    private func detectCampusNetwork() async -> Bool {
        guard let url = URL(string: "http://bkkq.xjtu.edu.cn/") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 3
        let session = URLSession(configuration: configuration)

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse) != nil
        } catch {
            return false
        }
    }

    private func loginWebVPN() async -> Bool {
        guard hasCredentials else {
            lastLoginError = "缺少账号或密码，无法登录 WebVPN"
            return false
        }

        let login = XJTULogin(
            loginURL: AppConstants.URLS.webVPNLoginURL,
            client: client,
            visitorID: cachedVisitorID,
            cachedRsaPublicKey: cachedRsaPublicKey
        )

        do {
            var result = try await login.login(username: savedUsername, password: savedPassword)
            if result.state == .requireAccountChoice {
                result = try await login.login(accountType: .undergraduate)
            }
            if result.state == .success {
                cachedVisitorID = login.fpVisitorId
                if let rsa = login.getRsaPublicKey() {
                    cachedRsaPublicKey = rsa
                }
                await persistRuntimeCache()
                return true
            }

            lastLoginError = "WebVPN 登录失败：\(loginFailureMessage(from: result))"
            return false
        } catch {
            lastLoginError = "WebVPN 登录失败：\(readableLoginError(error))"
            return false
        }
    }

    private func loginFailureMessage(from result: LoginResult) -> String {
        switch result.state {
        case .success:
            return "登录成功"
        case .requireMFA:
            return "登录需要二次验证，当前版本暂不支持"
        case .requireCaptcha:
            return "登录需要验证码，当前版本暂不支持"
        case .requireAccountChoice:
            return "需要选择账号类型，请确认是否为本科账号"
        case .fail:
            return result.message.isEmpty ? "登录失败，请检查凭据" : result.message
        }
    }

    private func readableLoginError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "网络请求超时，请稍后重试"
            case .notConnectedToInternet:
                return "网络未连接，请检查网络"
            case .cannotFindHost, .cannotConnectToHost:
                return "无法连接服务器，请检查网络或 VPN"
            default:
                return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
