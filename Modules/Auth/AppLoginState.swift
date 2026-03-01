import Foundation

@MainActor
final class AppLoginState: ObservableObject {
    @Published var activeUsername: String = ""
    @Published var isOnCampus: Bool?
    @Published var ywtbUserInfo: UserInfo?

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

    private var webVPNReady = false
    private var cachedVisitorID: String?
    private var cachedRsaPublicKey: String?

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

        if let credential = await credentialStore.loadCredential() {
            savedUsername = credential.username
            savedPassword = credential.password
            cachedVisitorID = await credentialStore.loadVisitorID()
            cachedRsaPublicKey = await credentialStore.loadRSAPublicKey()
        }

        guard hasCredentials else { return }

        // Warm up core systems; individual screens still lazy-login when entered.
        _ = await autoLogin(type: .jwxt)
        _ = await autoLogin(type: .jwapp)
        _ = await autoLogin(type: .ywtb)
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

        savedUsername = ""
        savedPassword = ""

        await credentialStore.clearAll()
        await CookiePersistence.shared.clear()
    }

    func autoLogin(type: LoginType) async -> XJTULogin? {
        if let cached = cachedLogin(for: type) {
            return cached
        }

        guard hasCredentials else {
            return nil
        }

        let needsInternalNetwork = type == .attendance || type == .library
        if needsInternalNetwork {
            if isOnCampus == nil {
                isOnCampus = await detectCampusNetwork()
            }
            if isOnCampus == false, !webVPNReady {
                webVPNReady = await loginWebVPN()
            }
        }

        let useWebVPN = needsInternalNetwork && isOnCampus == false

        let login = makeLogin(type: type, useWebVPN: useWebVPN)

        do {
            var result = try await login.login(username: savedUsername, password: savedPassword)
            if result.state == .requireAccountChoice {
                result = try await login.login(accountType: .undergraduate)
            }

            guard result.state == .success else {
                return nil
            }

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

            return login
        } catch {
            return nil
        }
    }

    func ensureLogin(type: LoginType) async -> Bool {
        await autoLogin(type: type) != nil
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
        guard hasCredentials else { return false }

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
            return false
        } catch {
            return false
        }
    }
}
