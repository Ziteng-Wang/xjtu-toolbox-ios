import Foundation

enum AppConstants {
    static let appName = "XJTU Toolbox"

    enum URLS {
        static let casLogin = "https://login.xjtu.edu.cn/cas/login"
        static let casPublicKey = "https://login.xjtu.edu.cn/cas/jwt/publicKey"
        static let attendanceURL = "http://org.xjtu.edu.cn/openplatform/oauth/authorize?appId=1372&redirectUri=http://bkkq.xjtu.edu.cn/berserker-auth/auth/attendance-pc/casReturn&responseType=code&scope=user_info&state=1234"
        static let attendanceWebVPNURL = "http://bkkq.xjtu.edu.cn"
        static let jwxtURL = "https://jwxt.xjtu.edu.cn/jwapp/sys/homeapp/index.do"
        static let jwappURL = "https://org.xjtu.edu.cn/openplatform/oauth/authorize?appId=1370&redirectUri=http://jwapp.xjtu.edu.cn/app/index&responseType=code&scope=user_info&state=1234"
        static let ywtbURL = "https://login.xjtu.edu.cn/cas/login?service=https%3A%2F%2Fywtb.xjtu.edu.cn%2F%3Fpath%3Dhttps%253A%252F%252Fywtb.xjtu.edu.cn%252Fmain.html%2523%252FIndex"
        static let librarySeatURL = "http://rg.lib.xjtu.edu.cn:8086/seat/"
        static let campusCardURL = "http://card.xjtu.edu.cn/Category/ContechFirstPage"
        static let gmisURL = "https://org.xjtu.edu.cn/openplatform/oauth/authorize?appId=1036&state=abcd1234&redirectUri=http://gmis.xjtu.edu.cn/pyxx/sso/login&responseType=code&scope=user_info"
        static let gsteURL = "https://cas.xjtu.edu.cn/login?TARGET=http%3A%2F%2Fgste.xjtu.edu.cn%2Flogin.do"
        static let webVPNLoginURL = "https://webvpn.xjtu.edu.cn/login?cas_login=true"
        static let curriculumOverviewURL = "https://jwxt.xjtu.edu.cn/jwapp/sys/xsfacx/*default/index.do?EMAP_LANG=zh&forceApp=xsfacx"
        static let curriculumCourseTreeURL = "https://jwxt.xjtu.edu.cn/jwapp/sys/jwpubapp/*default/index.do?EMAP_LANG=zh&forceApp=jwpubapp"
    }

    enum StorageKey {
        static let username = "xjtu.username"
        static let password = "xjtu.password"
        static let visitorID = "xjtu.fpVisitorId"
        static let rsaPublicKey = "xjtu.rsaPublicKey"
        static let rsaPublicKeyTime = "xjtu.rsaPublicKeyTime"
        static let cookies = "xjtu.cookies"
        static let nsaProfile = "xjtu.nsa.profile"
        static let nsaPhoto = "xjtu.nsa.photo"
        static let eulaAcceptedVersion = "xjtu.eula.accepted.version"
    }

    static let currentEulaVersion = 1
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
}
