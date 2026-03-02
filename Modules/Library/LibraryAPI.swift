import Foundation

struct SeatInfo: Identifiable, Hashable {
    var id: String { seatID }
    let seatID: String
    let available: Bool
}

struct AreaStats: Hashable {
    let available: Int
    let total: Int

    var isOpen: Bool { total > 0 }
    var label: String { "\(available)/\(total)" }
}

struct BookResult: Hashable {
    let success: Bool
    let message: String
    let finalURL: String
}

struct MyBookingInfo: Hashable {
    let seatID: String?
    let area: String?
    let statusText: String?
    let actionURLs: [String: String]
}

enum SeatResult {
    case success(seats: [SeatInfo], areaStats: [String: AreaStats])
    case authError(message: String, htmlPreview: String)
    case error(message: String)
}

final class LibraryAPI {
    static let baseURL = "http://rg.lib.xjtu.edu.cn:8086"

    static let areaMap: [String: String] = [
        "北楼二层外文厅(东)": "north2east",
        "二层连廊及流通大厅": "north2elian",
        "北楼二层外文厅(西)": "north2west",
        "南楼二层大厅": "south2",
        "北楼三层ILibrary-B(西)": "west3B",
        "大屏辅学空间": "eastnorthda",
        "南楼三层中段": "south3middle",
        "北楼三层ILibrary-A(东)": "east3A",
        "北楼四层西侧": "north4west",
        "北楼四层中间": "north4middle",
        "北楼四层东侧": "north4east",
        "北楼四层西南侧": "north4southwest",
        "北楼四层东南侧": "north4southeast"
    ]

    private let login: LibraryLogin

    private(set) var cachedAreaStats: [String: AreaStats] = [:]

    init(login: LibraryLogin) {
        self.login = login
    }

    func getSeats(areaCode: String) async -> SeatResult {
        guard await ensureSeatReady() else {
            return .authError(message: authMessage(fallback: "图书馆认证未完成"), htmlPreview: "")
        }

        do {
            var response = try await requestSeats(areaCode: areaCode)
            var body = response.bodyString

            if isRedirectedToLogin(body: body, finalURL: response.finalURL.absoluteString) {
                guard await ensureSeatReady() else {
                    return .authError(
                        message: authMessage(fallback: "认证失效，请重新登录"),
                        htmlPreview: String(body.prefix(200))
                    )
                }
                response = try await requestSeats(areaCode: areaCode)
                body = response.bodyString
                if isRedirectedToLogin(body: body, finalURL: response.finalURL.absoluteString) {
                    return .authError(
                        message: authMessage(fallback: "认证失效，请重新登录"),
                        htmlPreview: String(body.prefix(200))
                    )
                }
            }

            guard let root = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                return .error(message: "座位数据解析失败")
            }

            let statsRaw = root["scount"] as? [String: Any] ?? [:]
            var areaStats: [String: AreaStats] = [:]
            for (key, value) in statsRaw {
                guard let pair = value as? [Any], pair.count >= 2 else { continue }
                let available = int(pair[0], default: 0)
                let total = int(pair[1], default: 0)
                areaStats[key] = AreaStats(available: available, total: total)
            }
            cachedAreaStats = areaStats.filter { Self.areaMap.values.contains($0.key) }

            let seatRaw = root["seat"] as? [String: Any] ?? [:]
            let seats = seatRaw.map { key, value in
                let status = int(value, default: -1)
                return SeatInfo(seatID: key, available: status == 0)
            }.sorted { lhs, rhs in
                if lhs.seatID.first != rhs.seatID.first {
                    return lhs.seatID.first ?? "A" < rhs.seatID.first ?? "A"
                }
                let leftNum = Int(lhs.seatID.filter { $0.isNumber }) ?? 0
                let rightNum = Int(rhs.seatID.filter { $0.isNumber }) ?? 0
                return leftNum < rightNum
            }

            return .success(seats: seats, areaStats: cachedAreaStats)
        } catch {
            return .error(message: "座位请求失败: \(error.localizedDescription)")
        }
    }

    func bookSeat(seatID: String, areaCode: String, autoSwap: Bool = true) async -> BookResult {
        guard await ensureSeatReady() else {
            return BookResult(success: false, message: authMessage(fallback: "图书馆认证未完成"), finalURL: "")
        }

        do {
            let url = "\(Self.baseURL)/seat/?kid=\(seatID)&sp=\(areaCode)"
            let response = try await login.client.get(url, useWebVPN: login.useWebVPN)
            let body = response.bodyString
            let finalURL = response.finalURL.absoluteString

            if finalURL.contains("/my/") || finalURL.contains("/seat/my/") {
                return BookResult(success: true, message: "预约成功", finalURL: finalURL)
            }

            if autoSwap,
               body.contains("已有预约") || body.contains("换座") || body.contains("已经预约") {
                return await swapSeat(seatID: seatID, areaCode: areaCode)
            }

            return BookResult(success: false, message: parseBookingFailure(body), finalURL: finalURL)
        } catch {
            return BookResult(success: false, message: "预约失败: \(error.localizedDescription)", finalURL: "")
        }
    }

    func swapSeat(seatID: String, areaCode: String) async -> BookResult {
        do {
            let url = "\(Self.baseURL)/updateseat/?kid=\(seatID)&sp=\(areaCode)"
            let response = try await login.client.get(url, useWebVPN: login.useWebVPN)
            let body = response.bodyString
            let finalURL = response.finalURL.absoluteString
            let success = finalURL.contains("/my/") || body.contains("成功")
            return BookResult(
                success: success,
                message: success ? "换座成功" : parseBookingFailure(body),
                finalURL: finalURL
            )
        } catch {
            return BookResult(success: false, message: "换座失败: \(error.localizedDescription)", finalURL: "")
        }
    }

    func getMyBooking() async -> MyBookingInfo? {
        guard await ensureSeatReady() else {
            return nil
        }

        let candidateURLs = [
            "\(Self.baseURL)/seat/",
            "\(Self.baseURL)/my/",
            "\(Self.baseURL)/seat/my/",
            "\(Self.baseURL)/seat/my"
        ]

        for url in candidateURLs {
            do {
                let response = try await login.client.get(url, useWebVPN: login.useWebVPN)
                let body = response.bodyString
                if body.count < 50 || isRedirectedToLogin(body: body, finalURL: response.finalURL.absoluteString) {
                    continue
                }

                if body.contains("暂无") || body.contains("没有预约") || body.contains("无预约") {
                    return nil
                }

                if let seatID = body.firstMatch(pattern: #"([A-Z]\d{2,4})"#), !seatID.isEmpty {
                    let area = Self.areaMap.keys.first(where: { body.contains($0) })
                    let status = body.firstMatch(pattern: #"预约状态\s*[:：]\s*(\S+)"#)
                    let actions = parseActionURLs(from: body)
                    return MyBookingInfo(seatID: seatID, area: area, statusText: status, actionURLs: actions)
                }
            } catch {
                continue
            }
        }

        return nil
    }

    func executeAction(_ actionURL: String) async -> BookResult {
        guard await ensureSeatReady() else {
            return BookResult(success: false, message: authMessage(fallback: "图书馆认证未完成"), finalURL: "")
        }

        do {
            let absolute: String
            if actionURL.hasPrefix("http") {
                absolute = actionURL
            } else {
                absolute = URL(string: actionURL, relativeTo: URL(string: Self.baseURL))?.absoluteString ?? actionURL
            }

            let response = try await login.client.get(absolute, useWebVPN: login.useWebVPN)
            let body = response.bodyString
            let success = body.contains("成功") || response.finalURL.absoluteString.contains("/my/")
            return BookResult(
                success: success,
                message: success ? "操作成功" : parseBookingFailure(body),
                finalURL: response.finalURL.absoluteString
            )
        } catch {
            return BookResult(success: false, message: "操作失败: \(error.localizedDescription)", finalURL: "")
        }
    }

    func recommendSeats(_ seats: [SeatInfo], topN: Int = 5) -> [SeatInfo] {
        let available = seats.filter { $0.available }
        if available.count <= topN {
            return available
        }

        let grouped = Dictionary(grouping: seats) { $0.seatID.first ?? "A" }

        let scored = available.map { seat -> (SeatInfo, Int) in
            let row = grouped[seat.seatID.first ?? "A"] ?? []
            guard let idx = row.firstIndex(of: seat) else {
                return (seat, 0)
            }

            var score = 0
            if idx > 0, row[idx - 1].available { score += 2 }
            if idx + 1 < row.count, row[idx + 1].available { score += 2 }
            if idx > 0, idx + 1 < row.count, row[idx - 1].available, row[idx + 1].available { score += 3 }
            if idx == 0 || idx == row.count - 1 { score += 1 }
            return (seat, score)
        }

        return scored.sorted { $0.1 > $1.1 }.prefix(topN).map { $0.0 }
    }

    private var ajaxHeaders: [String: String] {
        [
            "X-Requested-With": "XMLHttpRequest",
            "Accept": "application/json, text/javascript, */*; q=0.01",
            "Referer": "\(Self.baseURL)/seat/"
        ]
    }

    private func requestSeats(areaCode: String) async throws -> HTTPResponse {
        try await login.client.get(
            "\(Self.baseURL)/qseat?sp=\(areaCode)",
            headers: ajaxHeaders,
            useWebVPN: login.useWebVPN
        )
    }

    private func ensureSeatReady() async -> Bool {
        if login.seatSystemReady {
            return true
        }
        return (try? await login.reAuthenticate()) == true
    }

    private func authMessage(fallback: String) -> String {
        login.diagnosticInfo.isEmpty ? fallback : login.diagnosticInfo
    }

    private func isRedirectedToLogin(body: String, finalURL: String) -> Bool {
        body.contains("id=\"loginForm\"") || body.contains("name=\"execution\"") || finalURL.contains("login.xjtu.edu.cn")
    }

    private func parseBookingFailure(_ html: String) -> String {
        if html.contains("30") && html.contains("分钟") {
            return "30 分钟内不可重复预约"
        }
        if html.contains("已被预约") {
            return "座位已被占用"
        }
        if html.contains("已有预约") {
            return "已有预约，请先取消"
        }
        if html.contains("不在预约时间") || html.contains("未开放") {
            return "当前不在预约开放时间"
        }
        if html.contains("维护") {
            return "系统维护中"
        }
        if html.contains("login") {
            return "登录状态失效"
        }
        return "预约失败"
    }

    private func parseActionURLs(from html: String) -> [String: String] {
        var result: [String: String] = [:]

        let mappings: [(label: String, action: String, queryKey: String)] = [
            ("取消预约", "cancel", "cancel"),
            ("签到", "ruguan1", "firstruguan"),
            ("临时离馆", "midleave", "midleave"),
            ("回馆签到", "midreturn", "midreturn")
        ]

        for mapping in mappings {
            let pattern = #"showConfirmModal\s*\(\s*['"][^'"]*['"]\s*,\s*'ACTION'\s*,\s*'(\d+)'\s*\)"#
                .replacingOccurrences(of: "ACTION", with: mapping.action)
            if let reserveID = html.firstMatch(pattern: pattern), !reserveID.isEmpty {
                result[mapping.label] = "\(Self.baseURL)/my/?\(mapping.queryKey)=1&ri=\(reserveID)"
            }
        }

        for mapping in mappings {
            let pattern = #"/my/\?QUERY=1&ri=(\d+)"#
                .replacingOccurrences(of: "QUERY", with: mapping.queryKey)
            if let reserveID = html.firstMatch(pattern: pattern), !reserveID.isEmpty {
                result[mapping.label] = "\(Self.baseURL)/my/?\(mapping.queryKey)=1&ri=\(reserveID)"
            }
        }

        return result
    }

    private func int(_ value: Any?, default defaultValue: Int) -> Int {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) ?? defaultValue }
        return defaultValue
    }
}
