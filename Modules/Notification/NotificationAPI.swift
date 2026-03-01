import Foundation

struct CampusNotification: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let link: String
    let source: NotificationSource
    let description: String
    let tags: [String]
    let date: Date
}

enum SourceCategory: String, CaseIterable, Identifiable {
    case teaching
    case engineering
    case science
    case info
    case humanities
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .teaching: return "教学管理"
        case .engineering: return "工学"
        case .science: return "理学"
        case .info: return "信息"
        case .humanities: return "人文经管"
        case .other: return "综合"
        }
    }
}

enum NotificationSource: String, CaseIterable, Identifiable {
    case jwc
    case gs
    case me
    case ee
    case epe
    case aero
    case mse
    case clet
    case hsce
    case math
    case phy
    case chem
    case se
    case som
    case rwxy
    case sfs
    case law
    case sef
    case sppa
    case marx
    case xmtxy
    case slst
    case qxs
    case fti
    case xsc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jwc: return "教务处"
        case .gs: return "研究生院"
        case .me: return "机械学院"
        case .ee: return "电气学院"
        case .epe: return "能动学院"
        case .aero: return "航天学院"
        case .mse: return "材料学院"
        case .clet: return "化工学院"
        case .hsce: return "人居学院"
        case .math: return "数学学院"
        case .phy: return "物理学院"
        case .chem: return "化学学院"
        case .se: return "软件学院"
        case .som: return "管理学院"
        case .rwxy: return "人文学院"
        case .sfs: return "外国语学院"
        case .law: return "法学院"
        case .sef: return "经金学院"
        case .sppa: return "公管学院"
        case .marx: return "马克思主义学院"
        case .xmtxy: return "新媒体学院"
        case .slst: return "生命学院"
        case .qxs: return "钱学森书院"
        case .fti: return "未来技术学院"
        case .xsc: return "学工部"
        }
    }

    var baseURL: String {
        switch self {
        case .jwc: return "https://dean.xjtu.edu.cn/jxxx/jxtz2.htm"
        case .gs: return "https://gs.xjtu.edu.cn/tzgg.htm"
        case .me: return "https://mec.xjtu.edu.cn/index/tzgg/bks.htm"
        case .ee: return "https://ee.xjtu.edu.cn/jzxx/bks.htm"
        case .epe: return "https://epe.xjtu.edu.cn/index/tzgg.htm"
        case .aero: return "https://sae.xjtu.edu.cn/index/tzgg.htm"
        case .mse: return "https://mse.xjtu.edu.cn/xwgg/tzgg1.htm"
        case .clet: return "https://clet.xjtu.edu.cn/xwgg/tzgg.htm"
        case .hsce: return "https://hsce.xjtu.edu.cn/xwgg/tzgg1.htm"
        case .math: return "https://math.xjtu.edu.cn/index/jxjw1.htm"
        case .phy: return "https://phy.xjtu.edu.cn/glfw/tzgg.htm"
        case .chem: return "https://chem.xjtu.edu.cn/tzgg.htm"
        case .se: return "https://se.xjtu.edu.cn/xwgg/tzgg.htm"
        case .som: return "https://som.xjtu.edu.cn/xwgg/tzgg.htm"
        case .rwxy: return "https://rwxy.xjtu.edu.cn/index/tzgg.htm"
        case .sfs: return "https://sfs.xjtu.edu.cn/glfw/jxjw.htm"
        case .law: return "https://fxy.xjtu.edu.cn/index/tzgg.htm"
        case .sef: return "https://sef.xjtu.edu.cn/rcpy/bks/jxtz1.htm"
        case .sppa: return "https://sppa.xjtu.edu.cn/xwxx/bksjw.htm"
        case .marx: return "https://marx.xjtu.edu.cn/xwgg1/tzgg.htm"
        case .xmtxy: return "https://xmtxy.xjtu.edu.cn/xwgg/tzgg.htm"
        case .slst: return "https://slst.xjtu.edu.cn/ggl/tzgg.htm"
        case .qxs: return "https://bjb.xjtu.edu.cn/xydt/tzgg.htm"
        case .fti: return "https://wljsxy.xjtu.edu.cn/xwgg/tzgg.htm"
        case .xsc: return "https://xsc.xjtu.edu.cn/xgdt/tzgg.htm"
        }
    }

    var category: SourceCategory {
        switch self {
        case .jwc, .gs:
            return .teaching
        case .me, .ee, .epe, .aero, .mse, .clet, .hsce:
            return .engineering
        case .math, .phy, .chem:
            return .science
        case .se:
            return .info
        case .som, .rwxy, .sfs, .law, .sef, .sppa, .marx, .xmtxy:
            return .humanities
        case .slst, .qxs, .fti, .xsc:
            return .other
        }
    }

    static func byCategory(_ category: SourceCategory) -> [NotificationSource] {
        allCases.filter { $0.category == category }
    }
}

final class NotificationAPI {
    private let client: HTTPClient

    init(client: HTTPClient = .shared) {
        self.client = client
    }

    func getNotifications(source: NotificationSource, page: Int = 1) async -> [CampusNotification] {
        var url = source.baseURL
        var result: [CampusNotification] = []

        for _ in 0..<max(1, page) {
            guard let html = try? await fetchHTML(url: url) else {
                break
            }

            let items = parseListItems(html: html, baseURL: url, source: source)
            result.append(contentsOf: items)

            guard let next = extractNextURL(from: html, baseURL: url), !next.isEmpty else {
                break
            }
            url = next
        }

        return deduplicate(result).sorted { $0.date > $1.date }
    }

    func getMergedNotifications(sources: [NotificationSource], page: Int = 1) async -> [CampusNotification] {
        var merged: [CampusNotification] = []
        for source in sources {
            let items = await getNotifications(source: source, page: page)
            merged.append(contentsOf: items)
        }
        return deduplicate(merged).sorted { $0.date > $1.date }
    }

    func getAllNotifications(page: Int = 1) async -> [CampusNotification] {
        await getMergedNotifications(sources: NotificationSource.allCases, page: page)
    }

    private func fetchHTML(url: String) async throws -> String {
        let response = try await client.get(url)
        if response.http.statusCode >= 400 {
            throw HTTPError.serverError(status: response.http.statusCode, message: "通知获取失败")
        }

        let html = response.bodyString
        if html.contains("dynamic_challenge"),
           let solved = try? await solveChallenge(from: html, url: url) {
            return solved
        }

        return html
    }

    private func solveChallenge(from html: String, url: String) async throws -> String {
        guard let challengeID = html.firstMatch(pattern: #"challengeId\s*=\s*"([^"]+)""#),
              let answer = html.firstMatch(pattern: #"answer\s*=\s*(\d+)"#),
              let base = URL(string: url),
              let baseURL = URL(string: "\(base.scheme ?? "https")://\(base.host ?? "")") else {
            return html
        }

        let payload: [String: Any] = [
            "challenge_id": challengeID,
            "answer": Int(answer) ?? 0,
            "browser_info": [
                "userAgent": AppConstants.userAgent,
                "language": "zh-CN",
                "platform": "iPhone",
                "cookieEnabled": true,
                "hardwareConcurrency": 4,
                "deviceMemory": 8,
                "timezone": "Asia/Shanghai"
            ]
        ]

        let challengeURL = baseURL.appendingPathComponent("dynamic_challenge").absoluteString
        let challengeResponse = try await client.post(challengeURL, json: payload)
        guard let object = try? JSONSerialization.jsonObject(with: challengeResponse.data) as? [String: Any],
              (object["success"] as? Bool) == true,
              let clientID = object["client_id"] as? String else {
            return html
        }

        let retried = try await client.get(url, headers: ["Cookie": "client_id=\(clientID)"])
        return retried.bodyString
    }

    private func parseListItems(html: String, baseURL: String, source: NotificationSource) -> [CampusNotification] {
        let liBlocks = html.allMatches(pattern: #"<li[^>]*>([\s\S]*?)</li>"#, options: [.caseInsensitive])

        var list: [CampusNotification] = []
        for block in liBlocks {
            guard let href = block.firstMatch(pattern: #"<a[^>]*href=["']([^"']+)["'][^>]*>"#, options: [.caseInsensitive]),
                  let rawTitle = block.firstMatch(pattern: #"<a[^>]*>([\s\S]*?)</a>"#, options: [.caseInsensitive]) else {
                continue
            }

            let title = rawTitle
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if title.count < 4 {
                continue
            }

            let dateString = block.firstMatch(pattern: #"(\d{4}[./-]\d{1,2}[./-]\d{1,2})"#) ?? ""
            let date = parseDate(dateString)
            let link = resolveURL(base: baseURL, relative: href)

            list.append(
                CampusNotification(
                    title: title,
                    link: link,
                    source: source,
                    description: "",
                    tags: [],
                    date: date
                )
            )
        }

        return list
    }

    private func extractNextURL(from html: String, baseURL: String) -> String? {
        let patterns = [
            #"<span[^>]*class=["'][^"']*p_next[^"']*["'][^>]*>[\s\S]*?<a[^>]*href=["']([^"']+)["']"#,
            #"<a[^>]*href=["']([^"']+)["'][^>]*>下一页</a>"#,
            #"<a[^>]*class=["'][^"']*next[^"']*["'][^>]*href=["']([^"']+)["']"#
        ]

        for pattern in patterns {
            if let next = html.firstMatch(pattern: pattern, options: [.caseInsensitive]) {
                return resolveURL(base: baseURL, relative: next)
            }
        }
        return nil
    }

    private func resolveURL(base: String, relative: String) -> String {
        if relative.hasPrefix("http") {
            return relative
        }
        guard let baseURL = URL(string: base) else {
            return relative
        }
        return URL(string: relative, relativeTo: baseURL)?.absoluteString ?? relative
    }

    private func parseDate(_ raw: String) -> Date {
        let value = raw.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-")
        return DateFormatter.ymd.date(from: value) ?? Date()
    }

    private func deduplicate(_ list: [CampusNotification]) -> [CampusNotification] {
        var seen = Set<String>()
        var result: [CampusNotification] = []
        for item in list {
            let key = "\(item.source.rawValue)|\(item.title)|\(item.link)"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }
        return result
    }
}
