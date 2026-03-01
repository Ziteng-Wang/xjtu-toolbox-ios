import Foundation

struct ReportedGrade: Identifiable, Hashable {
    let id = UUID()
    let courseName: String
    let coursePoint: Double
    let score: String
    let gpa: Double?
    let term: String
}

final class ScoreReportAPI {
    private let login: JwxtLogin

    init(login: JwxtLogin) {
        self.login = login
    }

    static func scoreToGPA(_ score: Any?) -> Double? {
        switch score {
        case let number as NSNumber:
            let value = number.doubleValue
            switch value {
            case 95...100: return 4.3
            case 90..<95: return 4.0
            case 85..<90: return 3.7
            case 81..<85: return 3.3
            case 78..<81: return 3.0
            case 75..<78: return 2.7
            case 72..<75: return 2.3
            case 68..<72: return 2.0
            case 64..<68: return 1.7
            case 60..<64: return 1.3
            default: return 0
            }
        case let raw as String:
            let value = raw
                .replacingOccurrences(of: "＋", with: "+")
                .replacingOccurrences(of: "－", with: "-")
                .removingInvisibleCharacters
                .uppercased()

            if let numeric = Double(value) {
                return scoreToGPA(numeric)
            }

            switch value {
            case "A+", "优+": return 4.3
            case "A", "优": return 4.0
            case "A-", "优-": return 3.7
            case "B+", "良+": return 3.3
            case "B", "良": return 3.0
            case "B-", "良-": return 2.7
            case "C+", "中+": return 2.3
            case "C", "中": return 2.0
            case "C-", "中-": return 1.7
            case "D", "及格": return 1.3
            case "F", "不及格": return 0.0
            case "通过", "不通过": return nil
            default: return nil
            }
        default:
            return nil
        }
    }

    func getReportedGrade(studentID: String, filterTerms: [String]? = nil) async throws -> [ReportedGrade] {
        let initURL = "https://jwxt.xjtu.edu.cn/jwapp/sys/frReport2/show.do?reportlet=bkdsglxjtu/XAJTDX_BDS_CJ.cpt&xh=\(studentID)"
        let initResponse = try await login.client.get(initURL)

        let sessionID = extractSessionID(from: initResponse.bodyString)
        guard !sessionID.isEmpty else {
            return []
        }

        var allCourses: [ReportedGrade] = []

        let firstPage = try await fetchFRPage(sessionID: sessionID, page: 1)
        allCourses.append(contentsOf: parseCourses(from: firstPage))
        let totalPages = extractTotalPages(from: firstPage)

        if totalPages > 1 {
            for page in 2...totalPages {
                let html = try await fetchFRPage(sessionID: sessionID, page: page)
                allCourses.append(contentsOf: parseCourses(from: html))
            }
        }

        guard let filterTerms else {
            return allCourses
        }
        return allCourses.filter { filterTerms.contains($0.term) }
    }

    private func fetchFRPage(sessionID: String, page: Int) async throws -> String {
        let now = Int(Date().timeIntervalSince1970 * 1000)
        let url = "https://jwxt.xjtu.edu.cn/jwapp/sys/frReport2/show.do?_=\(now)&__boxModel__=true&op=page_content&sessionID=\(sessionID)&pn=\(page)"
        return try await login.client.get(url).bodyString
    }

    private func extractSessionID(from html: String) -> String {
        html.firstMatch(pattern: #"FR\.SessionMgr\.register\(\s*['"](\d+)['"]"#, options: [.caseInsensitive])
            ?? html.firstMatch(pattern: #"sessionID=(\d+)"#, options: [.caseInsensitive])
            ?? ""
    }

    private func extractTotalPages(from html: String) -> Int {
        Int(html.firstMatch(pattern: #"FR\._p\.reportTotalPage\s*=\s*(\d+)"#) ?? "1") ?? 1
    }

    private func parseCourses(from html: String) -> [ReportedGrade] {
        let rows = html.allMatches(
            pattern: #"<tr[^>]*>([\s\S]*?)</tr>"#,
            options: [.caseInsensitive]
        )

        var currentTerm: String?
        var courses: [ReportedGrade] = []

        for row in rows {
            let cells = row.allMatches(
                pattern: #"<(?:td|th)[^>]*>([\s\S]*?)</(?:td|th)>"#,
                options: [.caseInsensitive]
            ).map { cell in
                cell.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if cells.count == 1 {
                let termText = cells[0]
                if let y1 = termText.firstMatch(pattern: #"(\d{4})\s*-\s*(\d{4})"#),
                   let y2 = termText.firstMatch(pattern: #"\d{4}\s*-\s*(\d{4})"#),
                   let sem = parseSemester(from: termText) {
                    currentTerm = "\(y1)-\(y2)-\(sem)"
                }
                continue
            }

            guard cells.count >= 3,
                  let currentTerm,
                  let credit = Double(cells[1]) else {
                continue
            }

            let name = cells[0]
            let score = cells[2]
            if ["课程", "学分", "成绩"].contains(name) {
                continue
            }

            courses.append(
                ReportedGrade(
                    courseName: name,
                    coursePoint: credit,
                    score: score,
                    gpa: Self.scoreToGPA(score),
                    term: currentTerm
                )
            )
        }

        return courses
    }

    private func parseSemester(from text: String) -> Int? {
        if text.contains("第一") || text.contains("一") {
            return 1
        }
        if text.contains("第二") || text.contains("二") {
            return 2
        }
        return nil
    }
}
