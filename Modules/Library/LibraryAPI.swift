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

    static func guessAreaCode(for seatID: String) -> String? {
        guard let prefix = seatID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().first else {
            return nil
        }

        switch prefix {
        case "A", "B":
            return "north2elian"
        case "D", "E":
            return "north2east"
        case "C":
            return "south2"
        case "N":
            return "north2west"
        case "Y":
            return "west3B"
        case "P":
            return "eastnorthda"
        case "X":
            return "east3A"
        case "K", "L", "M":
            return "north4west"
        case "J":
            return "north4middle"
        case "H", "F", "G":
            return "north4east"
        case "Q":
            return "north4southwest"
        case "T":
            return "north4southeast"
        default:
            return nil
        }
    }

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
            let normalizedSeatID = normalizedSeat(seatID)
            let resolvedAreaCode = resolveAreaCode(preferred: areaCode, seatID: normalizedSeatID)
            let url = "\(Self.baseURL)/seat/?kid=\(normalizedSeatID)&sp=\(resolvedAreaCode)"
            let response = try await requestSeatPage(url)
            let body = response.bodyString
            let bodyText = normalizedBodyText(body)
            let finalURL = response.finalURL.absoluteString

            if isMyBookingURL(finalURL) || bodyText.contains("预约成功") {
                return await verifyBookingSeat(
                    expectedSeatID: normalizedSeatID,
                    html: body,
                    finalURL: finalURL,
                    successMessage: "预约成功",
                    mismatchPrefix: "预约未生效，当前预约座位为"
                )
            }

            if autoSwap,
               bodyText.contains("已有预约") || bodyText.contains("已预约") || bodyText.contains("换座") ||
                bodyText.contains("已经预约") || bodyText.contains("存在预约") {
                return await swapSeat(seatID: normalizedSeatID, areaCode: resolvedAreaCode)
            }

            return BookResult(success: false, message: parseBookingFailure(body), finalURL: finalURL)
        } catch {
            return BookResult(success: false, message: "预约失败: \(error.localizedDescription)", finalURL: "")
        }
    }

    func swapSeat(seatID: String, areaCode: String) async -> BookResult {
        do {
            let normalizedSeatID = normalizedSeat(seatID)
            let resolvedAreaCode = resolveAreaCode(preferred: areaCode, seatID: normalizedSeatID)
            let url = "\(Self.baseURL)/updateseat/?kid=\(normalizedSeatID)&sp=\(resolvedAreaCode)"
            let response = try await requestSeatPage(url)
            let body = response.bodyString
            let bodyText = normalizedBodyText(body)
            let finalURL = response.finalURL.absoluteString
            let looksSuccessful = isMyBookingURL(finalURL) || bodyText.contains("成功换座") || bodyText.contains("成功")
            if looksSuccessful {
                return await verifyBookingSeat(
                    expectedSeatID: normalizedSeatID,
                    html: body,
                    finalURL: finalURL,
                    successMessage: "换座成功",
                    mismatchPrefix: "换座未生效，当前预约座位为"
                )
            }
            return BookResult(success: false, message: parseBookingFailure(body), finalURL: finalURL)
        } catch {
            return BookResult(success: false, message: "换座失败: \(error.localizedDescription)", finalURL: "")
        }
    }

    func getMyBooking() async -> MyBookingInfo? {
        guard await ensureSeatReady() else {
            return nil
        }

        var candidateURLs: [String] = []
        if let mainResponse = try? await requestSeatPage("\(Self.baseURL)/seat/") {
            let mainBody = mainResponse.bodyString
            if mainBody.count >= 50,
               !isRedirectedToLogin(body: mainBody, finalURL: mainResponse.finalURL.absoluteString) {
                if let discovered = extractMyBookingLink(from: mainBody, baseURL: mainResponse.finalURL) {
                    candidateURLs.append(discovered)
                }
            }
        }

        candidateURLs.append(contentsOf: [
            "\(Self.baseURL)/my/",
            "\(Self.baseURL)/seat/my/",
            "\(Self.baseURL)/seat/my"
        ])

        var seen = Set<String>()
        candidateURLs = candidateURLs.filter { seen.insert($0).inserted }

        for url in candidateURLs {
            do {
                let response = try await requestSeatPage(url)
                let body = response.bodyString
                if body.count < 50 || isRedirectedToLogin(body: body, finalURL: response.finalURL.absoluteString) {
                    continue
                }

                let bodyText = normalizedBodyText(body)
                if (bodyText.contains("Not Found") || bodyText.contains("404")) && bodyText.count < 800 {
                    continue
                }

                if !containsSeatID(in: bodyText), containsNoBookingHint(in: bodyText) {
                    return nil
                }

                if let parsed = parseActiveBooking(from: body) {
                    return parsed
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

            let response = try await requestSeatPage(absolute)
            let body = response.bodyString
            let bodyText = normalizedBodyText(body)
            let success = bodyText.contains("成功") || bodyText.contains("已取消") ||
                bodyText.contains("取消成功") || isMyBookingURL(response.finalURL.absoluteString)
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
            "Referer": seatReferer
        ]
    }

    private var seatPageHeaders: [String: String] {
        [
            "Referer": seatReferer
        ]
    }

    private var seatReferer: String {
        "\(Self.baseURL)/seat/"
    }

    private func requestSeats(areaCode: String) async throws -> HTTPResponse {
        try await login.client.get(
            "\(Self.baseURL)/qseat?sp=\(areaCode)",
            headers: ajaxHeaders,
            useWebVPN: login.useWebVPN
        )
    }

    private func requestSeatPage(_ url: String, retryOnAuthFailure: Bool = true) async throws -> HTTPResponse {
        let response = try await login.client.get(
            url,
            headers: seatPageHeaders,
            useWebVPN: login.useWebVPN
        )

        guard retryOnAuthFailure else {
            return response
        }

        if isRedirectedToLogin(body: response.bodyString, finalURL: response.finalURL.absoluteString),
           (try? await login.reAuthenticate()) == true {
            return try await requestSeatPage(url, retryOnAuthFailure: false)
        }

        return response
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
        body.contains("id=\"loginForm\"") || body.contains("name=\"execution\"") ||
            body.contains("cas/login") || body.contains("统一身份认证") ||
            (body.contains("name=\"username\"") && body.contains("name=\"password\"")) ||
            finalURL.contains("login.xjtu.edu.cn") ||
            (finalURL.contains("webvpn.xjtu.edu.cn") && (finalURL.contains("/login") || finalURL.contains("/auth")))
    }

    private func parseBookingFailure(_ html: String) -> String {
        let bodyText = normalizedBodyText(html)
        if bodyText.contains("30分钟") || bodyText.contains("30 分钟") || bodyText.localizedCaseInsensitiveContains("30 min") {
            return "30 分钟内不可重复预约"
        }
        if bodyText.contains("已被预约") || bodyText.contains("已被占") {
            return "座位已被占用"
        }
        if bodyText.contains("已有预约") || bodyText.contains("已预约") || bodyText.contains("已经预约") || bodyText.contains("存在预约") {
            return "已有预约，请先取消"
        }
        if bodyText.contains("不在预约时间") || bodyText.contains("未开放") {
            return "当前不在预约开放时间"
        }
        if bodyText.contains("维护") {
            return "系统维护中"
        }
        if bodyText.contains("登录") || html.contains("login") {
            return "登录状态失效"
        }
        if let hint = bodyText.split(separator: " ").first(where: {
            $0.contains("预约") || $0.contains("失败") || $0.contains("错误") || $0.contains("登录")
        }) {
            return String(hint.prefix(32))
        }
        return "预约失败"
    }

    private func verifyBookingSeat(
        expectedSeatID: String,
        html: String,
        finalURL: String,
        successMessage: String,
        mismatchPrefix: String
    ) async -> BookResult {
        let normalizedExpected = normalizedSeat(expectedSeatID)
        let landedOnMyPage = isMyBookingURL(finalURL)
        let bodyText = normalizedBodyText(html)

        if let seatInPage = extractSeatID(from: html) {
            if seatInPage.caseInsensitiveCompare(normalizedExpected) == .orderedSame {
                return BookResult(success: true, message: successMessage, finalURL: finalURL)
            }
            if landedOnMyPage {
                return BookResult(
                    success: true,
                    message: "\(successMessage)，页面显示 \(seatInPage)，请在“我的预约”核对",
                    finalURL: finalURL
                )
            }
            return BookResult(success: false, message: "\(mismatchPrefix) \(seatInPage)", finalURL: finalURL)
        }

        if let booking = await getMyBookingWithRetry(maxAttempts: 3),
           let currentSeat = booking.seatID,
           !currentSeat.isEmpty {
            if currentSeat.caseInsensitiveCompare(normalizedExpected) == .orderedSame {
                return BookResult(success: true, message: successMessage, finalURL: finalURL)
            }
            if landedOnMyPage {
                return BookResult(
                    success: true,
                    message: "\(successMessage)，当前预约显示为 \(currentSeat)，请手动确认",
                    finalURL: finalURL
                )
            }
            return BookResult(success: false, message: "\(mismatchPrefix) \(currentSeat)", finalURL: finalURL)
        }

        if landedOnMyPage {
            return BookResult(success: true, message: "\(successMessage)，请在“我的预约”确认结果", finalURL: finalURL)
        }

        if hasSuccessHint(in: bodyText), !hasExplicitFailureHint(in: bodyText) {
            return BookResult(success: true, message: "\(successMessage)，系统返回成功提示，请手动确认", finalURL: finalURL)
        }

        return BookResult(success: false, message: "预约结果未生效，请稍后重试", finalURL: finalURL)
    }

    private func isMyBookingURL(_ url: String) -> Bool {
        url.contains("/my/") || url.hasSuffix("/my") || url.contains("/seat/my/") || url.hasSuffix("/seat/my")
    }

    private func extractSeatID(from html: String) -> String? {
        extractSeatIDFromBookingContext(normalizedBodyText(html))
    }

    private func normalizedBodyText(_ html: String) -> String {
        var text = html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)

        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&#x27;": "'"
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }

        return text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func parseActiveBooking(from html: String) -> MyBookingInfo? {
        let bodyText = normalizedBodyText(html)
        let actions = parseActionURLs(from: html)
        let inactiveStatuses: Set<String> = ["已取消", "已完成", "已过期", "已失效", "已违约", "超时取消"]

        let statusRegex = try? NSRegularExpression(pattern: #"预约状态\s*[:：]\s*(\S+)"#, options: [])
        let fullRange = NSRange(bodyText.startIndex..., in: bodyText)
        let matches = statusRegex?.matches(in: bodyText, options: [], range: fullRange) ?? []

        if matches.isEmpty {
            guard let seatID = extractLastSeatID(from: bodyText) else {
                return nil
            }
            return MyBookingInfo(
                seatID: seatID,
                area: extractAreaName(from: bodyText),
                statusText: nil,
                actionURLs: actions
            )
        }

        var blockStart = bodyText.startIndex
        for match in matches {
            guard match.numberOfRanges > 1,
                  let statusRange = Range(match.range(at: 1), in: bodyText),
                  let blockEnd = Range(match.range, in: bodyText)?.upperBound else {
                continue
            }

            let status = String(bodyText[statusRange])
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            let blockText = String(bodyText[blockStart..<blockEnd])
            blockStart = blockEnd

            if inactiveStatuses.contains(where: { status.contains($0) }) {
                continue
            }

            let beforeSeat = nearestSeatID(in: bodyText, around: statusRange.lowerBound, lookBackward: true)
            let afterSeat = nearestSeatID(in: bodyText, around: statusRange.upperBound, lookBackward: false)
            let contextText = textWindow(in: bodyText, around: statusRange.lowerBound)
            let blockSeat = extractLastSeatID(from: blockText)
            guard let seatID = beforeSeat ?? afterSeat ?? blockSeat else {
                continue
            }

            return MyBookingInfo(
                seatID: seatID,
                area: extractAreaName(from: contextText) ?? extractAreaName(from: blockText) ?? extractAreaName(from: bodyText),
                statusText: status,
                actionURLs: actions
            )
        }

        guard let fallbackSeat = extractLastSeatID(from: bodyText) else {
            return nil
        }
        return MyBookingInfo(
            seatID: fallbackSeat,
            area: extractAreaName(from: bodyText),
            statusText: nil,
            actionURLs: actions
        )
    }

    private func extractMyBookingLink(from html: String, baseURL: URL) -> String? {
        let linkPattern = #"<a[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, options: [], range: nsRange) {
            guard match.numberOfRanges > 2,
                  let hrefRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html) else {
                continue
            }

            let href = String(html[hrefRange])
            let text = normalizedBodyText(String(html[textRange]))
            if text.contains("我预约的座位") || text.contains("我的预约") || href.lowercased().contains("mybooking") {
                return URL(string: href, relativeTo: baseURL)?.absoluteString
            }
        }

        return nil
    }

    private func normalizedSeat(_ seatID: String) -> String {
        seatID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func resolveAreaCode(preferred: String, seatID: String) -> String {
        if Self.areaMap.values.contains(preferred) {
            return preferred
        }
        if let guessed = Self.guessAreaCode(for: seatID) {
            return guessed
        }
        return preferred
    }

    private func containsSeatID(in text: String) -> Bool {
        text.firstMatch(pattern: #"([A-Z]\d{2,4})"#, options: [.caseInsensitive]) != nil
    }

    private func containsNoBookingHint(in text: String) -> Bool {
        ["暂无预约", "没有预约", "无预约", "暂无"].contains { text.contains($0) }
    }

    private func extractAreaName(from text: String) -> String? {
        Self.areaMap.keys.first(where: { text.contains($0) })
    }

    private func extractLastSeatID(from text: String) -> String? {
        text.allMatches(pattern: #"([A-Z]\d{2,4})"#, options: [.caseInsensitive]).last?.uppercased()
    }

    private func extractSeatIDFromBookingContext(_ bodyText: String) -> String? {
        let patterns = [
            #"座位(?:号|編号|编号)?\s*[:：]?\s*([A-Z]\d{2,4})"#,
            #"预约(?:到|为)?\s*([A-Z]\d{2,4})"#,
            #"([A-Z]\d{2,4})\s*(?:预约成功|成功换座|换座成功)"#
        ]

        for pattern in patterns {
            if let value = bodyText.firstMatch(pattern: pattern, options: [.caseInsensitive]) {
                return value.uppercased()
            }
        }

        return nil
    }

    private func textWindow(in text: String, around center: String.Index, before: Int = 180, after: Int = 180) -> String {
        let start = text.index(center, offsetBy: -before, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(center, offsetBy: after, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end])
    }

    private func nearestSeatID(in text: String, around center: String.Index, lookBackward: Bool, window: Int = 220) -> String? {
        if lookBackward {
            let start = text.index(center, offsetBy: -window, limitedBy: text.startIndex) ?? text.startIndex
            let snippet = String(text[start..<center])
            return snippet.allMatches(pattern: #"([A-Z]\d{2,4})"#, options: [.caseInsensitive]).last?.uppercased()
        }

        let end = text.index(center, offsetBy: window, limitedBy: text.endIndex) ?? text.endIndex
        let snippet = String(text[center..<end])
        return snippet.firstMatch(pattern: #"([A-Z]\d{2,4})"#, options: [.caseInsensitive])?.uppercased()
    }

    private func getMyBookingWithRetry(maxAttempts: Int, delayNanoseconds: UInt64 = 280_000_000) async -> MyBookingInfo? {
        guard maxAttempts > 0 else { return nil }

        for attempt in 0..<maxAttempts {
            if let booking = await getMyBooking() {
                return booking
            }
            if attempt + 1 < maxAttempts {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }

        return nil
    }

    private func hasSuccessHint(in bodyText: String) -> Bool {
        bodyText.contains("预约成功") || bodyText.contains("换座成功") || bodyText.contains("成功换座") || bodyText.contains("操作成功")
    }

    private func hasExplicitFailureHint(in bodyText: String) -> Bool {
        let hints = ["失败", "未生效", "不在预约时间", "未开放", "已有预约", "已预约", "已被预约", "已被占", "维护", "登录状态失效", "错误"]
        return hints.contains { bodyText.contains($0) }
    }

    private func int(_ value: Any?, default defaultValue: Int) -> Int {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) ?? defaultValue }
        return defaultValue
    }
}
