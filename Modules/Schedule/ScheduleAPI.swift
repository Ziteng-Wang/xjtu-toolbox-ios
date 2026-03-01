import Foundation

struct CourseItem: Identifiable, Hashable {
    let id = UUID()
    let courseName: String
    let teacher: String
    let location: String
    let weekBits: String
    let dayOfWeek: Int
    let startSection: Int
    let endSection: Int
    let courseCode: String
    let courseType: String

    func weeks() -> [Int] {
        weekBits.enumerated().compactMap { idx, char in
            char == "1" ? idx + 1 : nil
        }
    }

    func isInWeek(_ week: Int) -> Bool {
        let bits = Array(weekBits)
        let index = week - 1
        guard bits.indices.contains(index) else {
            return false
        }
        return bits[index] == "1"
    }
}

struct ExamItem: Identifiable, Hashable {
    let id = UUID()
    let courseName: String
    let courseCode: String
    let examDate: String
    let examTime: String
    let location: String
    let seatNumber: String
}

struct TextbookItem: Identifiable, Hashable {
    let id = UUID()
    let courseName: String
    let textbookName: String
    let author: String
    let publisher: String
    let isbn: String
    let price: String
    let edition: String
}

final class ScheduleAPI {
    private let login: JwxtLogin
    private let baseURL = "https://jwxt.xjtu.edu.cn"
    private var cachedTermCode: String?

    init(login: JwxtLogin) {
        self.login = login
    }

    func getCurrentTerm() async throws -> String {
        if let cachedTermCode {
            return cachedTermCode
        }

        let response = try await login.client.post(
            "\(baseURL)/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do",
            form: [:],
            contentType: "application/x-www-form-urlencoded"
        )

        let json = try jsonObject(response.data)
        let data = json["datas"] as? [String: Any]
        let dqxnxq = data?["dqxnxq"] as? [String: Any]
        let rows = dqxnxq?["rows"] as? [[String: Any]]
        let code = rows?.first?["DM"] as? String ?? ""

        cachedTermCode = code
        return code
    }

    func getSchedule(termCode: String? = nil) async throws -> [CourseItem] {
        let term = try await resolvedTerm(termCode)
        let response = try await login.client.post(
            "\(baseURL)/jwapp/sys/wdkb/modules/xskcb/xskcb.do",
            form: ["XNXQDM": term]
        )

        let json = try jsonObject(response.data)
        let rows = (((json["datas"] as? [String: Any])?["xskcb"] as? [String: Any])?["rows"] as? [[String: Any]]) ?? []

        return rows.map { item in
            let courseType = (item["KCXZMC"] as? String)
                ?? (item["KCXZDM_DISPLAY"] as? String)
                ?? (item["KCFLMC"] as? String)
                ?? ""
            return CourseItem(
                courseName: item["KCM"] as? String ?? "",
                teacher: item["SKJS"] as? String ?? "",
                location: item["JASMC"] as? String ?? "",
                weekBits: item["SKZC"] as? String ?? "",
                dayOfWeek: int(item["SKXQ"], default: 1),
                startSection: int(item["KSJC"], default: 1),
                endSection: int(item["JSJC"], default: 1),
                courseCode: item["KCH"] as? String ?? "",
                courseType: courseType
            )
        }
    }

    func getExamSchedule(termCode: String? = nil) async throws -> [ExamItem] {
        let term = try await resolvedTerm(termCode)
        let response = try await login.client.post(
            "\(baseURL)/jwapp/sys/studentWdksapApp/modules/wdksap/wdksap.do",
            form: [
                "XNXQDM": term,
                "*order": "-KSRQ,-KSSJMS"
            ]
        )

        let json = try jsonObject(response.data)
        let rows = (((json["datas"] as? [String: Any])?["wdksap"] as? [String: Any])?["rows"] as? [[String: Any]]) ?? []

        return rows.map { item in
            let rawDate = item["KSRQ"] as? String ?? ""
            let examDate = rawDate.components(separatedBy: " ").first ?? rawDate
            let rawTime = item["KSSJMS"] as? String ?? ""
            let examTime = rawTime.replacingOccurrences(of: examDate, with: "").trimmingCharacters(in: .whitespacesAndNewlines)

            return ExamItem(
                courseName: (item["KCM"] as? String) ?? (item["KCMC"] as? String) ?? (item["KCH"] as? String) ?? "",
                courseCode: item["KCH"] as? String ?? "",
                examDate: examDate,
                examTime: examTime.isEmpty ? rawTime : examTime,
                location: item["JASMC"] as? String ?? "",
                seatNumber: item["ZWH"] as? String ?? ""
            )
        }
    }

    func getStartOfTerm(termCode: String? = nil) async throws -> Date {
        let term = try await resolvedTerm(termCode)
        let parts = term.split(separator: "-")
        guard parts.count == 3 else {
            throw HTTPError.invalidResponse
        }

        let response = try await login.client.post(
            "\(baseURL)/jwapp/sys/wdkb/modules/jshkcb/cxjcs.do",
            form: [
                "XN": "\(parts[0])-\(parts[1])",
                "XQ": String(parts[2])
            ]
        )

        let json = try jsonObject(response.data)
        let rows = (((json["datas"] as? [String: Any])?["cxjcs"] as? [String: Any])?["rows"] as? [[String: Any]]) ?? []
        guard let dateString = rows.first?["XQKSRQ"] as? String else {
            throw HTTPError.invalidResponse
        }
        let pureDate = dateString.components(separatedBy: " ").first ?? dateString
        guard let date = DateFormatter.ymd.date(from: pureDate) else {
            throw HTTPError.invalidResponse
        }
        return date
    }

    func getTextbooks(studentID: String, termCode: String? = nil) async throws -> [TextbookItem] {
        let term = try await resolvedTerm(termCode)
        let initURL = "\(baseURL)/jwapp/sys/frReport2/show.do?reportlet=jcgl/wdjc.cpt&xh=\(studentID)&xnxqdm=\(term)"

        let initResponse = try await login.client.get(initURL)
        let sessionID = extractFRSessionID(from: initResponse.bodyString)
        guard !sessionID.isEmpty else {
            return []
        }

        var allItems: [TextbookItem] = []

        let firstPage = try await fetchFRPage(sessionID: sessionID, page: 1)
        allItems.append(contentsOf: parseTextbooks(from: firstPage))

        let totalPages = extractFRTotalPages(from: firstPage)
        if totalPages > 1 {
            for page in 2...totalPages {
                let html = try await fetchFRPage(sessionID: sessionID, page: page)
                allItems.append(contentsOf: parseTextbooks(from: html))
            }
        }

        return allItems
    }

    func getTermList() async throws -> [String] {
        let response = try await login.client.post(
            "\(baseURL)/jwapp/sys/wdkb/modules/jshkcb/cxxnxqgl.do",
            form: [:],
            contentType: "application/x-www-form-urlencoded"
        )

        if let json = try? jsonObject(response.data),
           let rows = (((json["datas"] as? [String: Any])?["cxxnxqgl"] as? [String: Any])?["rows"] as? [[String: Any]] {
            let terms = rows.compactMap { $0["DM"] as? String }
            if !terms.isEmpty {
                return terms
            }
        }

        return try await generateRecentTerms()
    }

    private func fetchFRPage(sessionID: String, page: Int) async throws -> String {
        let now = Int(Date().timeIntervalSince1970 * 1000)
        let url = "\(baseURL)/jwapp/sys/frReport2/show.do?_=\(now)&__boxModel__=true&op=page_content&sessionID=\(sessionID)&pn=\(page)"
        let response = try await login.client.get(url)
        return response.bodyString
    }

    private func extractFRSessionID(from html: String) -> String {
        html.firstMatch(pattern: #"FR\.SessionMgr\.register\(\s*['"](\d+)['"]"#, options: [.caseInsensitive])
            ?? html.firstMatch(pattern: #"sessionID=(\d+)"#, options: [.caseInsensitive])
            ?? html.firstMatch(pattern: #"currentSessionID\s*=\s*['"](\d+)['"]"#, options: [.caseInsensitive])
            ?? ""
    }

    private func extractFRTotalPages(from html: String) -> Int {
        Int(html.firstMatch(pattern: #"FR\._p\.reportTotalPage\s*=\s*(\d+)"#) ?? "1") ?? 1
    }

    private func parseTextbooks(from html: String) -> [TextbookItem] {
        // Use table row fallback parser because FR HTML is highly dynamic.
        let rowRegex = try? NSRegularExpression(
            pattern: #"<tr[^>]*>([\s\S]*?)</tr>"#,
            options: [.caseInsensitive]
        )
        let cellRegex = try? NSRegularExpression(
            pattern: #"<(?:td|th)[^>]*>([\s\S]*?)</(?:td|th)>"#,
            options: [.caseInsensitive]
        )

        guard let rowRegex, let cellRegex else {
            return []
        }

        var rows: [[String]] = []
        let nsRange = NSRange(html.startIndex..., in: html)
        for rowMatch in rowRegex.matches(in: html, range: nsRange) {
            guard let rowRange = Range(rowMatch.range(at: 1), in: html) else { continue }
            let rowHTML = String(html[rowRange])
            let cellRange = NSRange(rowHTML.startIndex..., in: rowHTML)
            let cells = cellRegex.matches(in: rowHTML, range: cellRange).compactMap { match -> String? in
                guard let contentRange = Range(match.range(at: 1), in: rowHTML) else { return nil }
                let raw = String(rowHTML[contentRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return raw.isEmpty ? nil : raw
            }
            if cells.count >= 4 {
                rows.append(cells)
            }
        }

        guard rows.count > 1 else {
            return []
        }

        var output: [TextbookItem] = []
        for cells in rows.dropFirst() {
            let courseName = cells[safe: 1] ?? cells[safe: 0] ?? ""
            let textbookName = cells[safe: 3] ?? cells[safe: 1] ?? ""
            if courseName.isEmpty, textbookName.isEmpty {
                continue
            }

            output.append(
                TextbookItem(
                    courseName: courseName,
                    textbookName: textbookName,
                    author: cells[safe: 5] ?? cells[safe: 2] ?? "",
                    publisher: cells[safe: 7] ?? cells[safe: 3] ?? "",
                    isbn: cells[safe: 4] ?? "",
                    price: cells[safe: 6] ?? "",
                    edition: cells[safe: 6] ?? ""
                )
            )
        }

        return output
    }

    private func generateRecentTerms() async throws -> [String] {
        let current = try await getCurrentTerm()
        let parts = current.split(separator: "-")
        guard parts.count == 3,
              var firstYear = Int(parts[0]),
              var secondYear = Int(parts[1]),
              var semester = Int(parts[2]) else {
            return []
        }

        var result: [String] = []
        for _ in 0..<6 {
            result.append("\(firstYear)-\(secondYear)-\(semester)")
            if semester == 1 {
                firstYear -= 1
                secondYear -= 1
                semester = 2
            } else {
                semester = 1
            }
        }
        return result
    }

    private func resolvedTerm(_ termCode: String?) async throws -> String {
        if let termCode {
            return termCode
        }
        return try await getCurrentTerm()
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let result = object as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        return result
    }

    private func int(_ value: Any?, default defaultValue: Int) -> Int {
        if let int = value as? Int {
            return int
        }
        if let string = value as? String {
            return Int(string) ?? defaultValue
        }
        if let double = value as? Double {
            return Int(double)
        }
        return defaultValue
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
