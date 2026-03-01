import Foundation

struct GmisScheduleItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let teacher: String
    let classroom: String
    let weeks: String
    let dayOfWeek: Int
    let periodStart: Int
    let periodEnd: Int

    func weekList() -> [Int] {
        guard let match = weeks.firstMatch(pattern: #"(\d+)-(\d+)"#),
              let start = Int(match),
              let endMatch = weeks.firstMatch(pattern: #"\d+-(\d+)"#),
              let end = Int(endMatch) else {
            return []
        }
        return Array(start...end)
    }
}

struct GmisScoreItem: Identifiable, Hashable {
    let id = UUID()
    let courseName: String
    let coursePoint: Double
    let score: Double
    let type: String
    let examDate: String
    let gpa: Double
}

final class GmisAPI {
    private let login: GmisLogin

    init(login: GmisLogin) {
        self.login = login
    }

    func getCurrentTerm() async throws -> String {
        let html = try await fetchSchedulePage()
        let selected = html.firstMatch(pattern: #"<select[^>]*id=["']drpxq["'][^>]*>[\s\S]*?<option[^>]*selected[^>]*>([^<]+)</option>"#, options: [.caseInsensitive]) ?? ""
        return termToTimestamp(selected)
    }

    func getSchedule(timestamp: String? = nil) async throws -> [GmisScheduleItem] {
        if let timestamp {
            let term = timestampToTerm(timestamp)
            let page = try await fetchSchedulePage()
            let optionPattern = #"<option[^>]*value=["']([^"']+)["'][^>]*>\#(NSRegularExpression.escapedPattern(for: term))</option>"#
            let value = page.firstMatch(pattern: optionPattern, options: [.caseInsensitive])
            guard let value else {
                return parseSchedule(page)
            }
            let response = try await login.client.get("https://gmis.xjtu.edu.cn/pyxx/pygl/xskbcx/index/\(value)")
            return parseSchedule(response.bodyString)
        }
        let html = try await fetchSchedulePage()
        return parseSchedule(html)
    }

    func getScore() async throws -> [GmisScoreItem] {
        let response = try await login.client.get("https://gmis.xjtu.edu.cn/pyxx/pygl/xscjcx/index")
        let html = response.bodyString

        let rowPattern = try NSRegularExpression(pattern: #"<tr[^>]*>([\s\S]*?)</tr>"#, options: [.caseInsensitive])
        let cellPattern = try NSRegularExpression(pattern: #"<td[^>]*>([\s\S]*?)</td>"#, options: [.caseInsensitive])
        let nsRange = NSRange(html.startIndex..., in: html)

        var list: [GmisScoreItem] = []
        for row in rowPattern.matches(in: html, range: nsRange) {
            guard let rowRange = Range(row.range(at: 1), in: html) else { continue }
            let content = String(html[rowRange])
            let cellRange = NSRange(content.startIndex..., in: content)
            let cells = cellPattern.matches(in: content, range: cellRange).compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: content) else { return nil }
                return String(content[range])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard cells.count >= 5,
                  let score = Double(cells[3]),
                  let credit = Double(cells[1]) else { continue }

            list.append(
                GmisScoreItem(
                    courseName: cells[0],
                    coursePoint: credit,
                    score: score,
                    type: "研究生课程",
                    examDate: cells[4],
                    gpa: scoreToGPA(score)
                )
            )
        }

        return list
    }

    private func fetchSchedulePage() async throws -> String {
        let response = try await login.client.get("https://gmis.xjtu.edu.cn/pyxx/pygl/xskbcx")
        return response.bodyString
    }

    private func parseSchedule(_ html: String) -> [GmisScheduleItem] {
        let pattern = try? NSRegularExpression(
            pattern: #"document\.getElementById\(\"td_(\d+)_(\d+)\"\);[\s\S]*?td\.innerHTML\+=\"([^\"]+)\";"#,
            options: []
        )
        guard let pattern else { return [] }
        let range = NSRange(html.startIndex..., in: html)

        var output: [GmisScheduleItem] = []
        for match in pattern.matches(in: html, range: range) {
            guard let dayRange = Range(match.range(at: 1), in: html),
                  let contentRange = Range(match.range(at: 3), in: html) else {
                continue
            }

            let day = Int(html[dayRange]) ?? 1
            let text = String(html[contentRange])

            guard let name = text.firstMatch(pattern: "课程：([^<]+)"),
                  let teacher = text.firstMatch(pattern: "教师：([^<]+)"),
                  let classroom = text.firstMatch(pattern: "教室：([^<]+)"),
                  let periods = text.firstMatch(pattern: "节次：([^<]+)"),
                  let weeks = text.firstMatch(pattern: "周次：([^<]+)") else {
                continue
            }

            let periodParts = periods.split(separator: "-")
            let start = Int(periodParts.first ?? "0") ?? 0
            let end = Int(periodParts.last ?? "0") ?? start

            output.append(
                GmisScheduleItem(
                    name: name,
                    teacher: teacher,
                    classroom: classroom,
                    weeks: weeks,
                    dayOfWeek: day,
                    periodStart: start,
                    periodEnd: end
                )
            )
        }

        return output
    }

    private func timestampToTerm(_ timestamp: String) -> String {
        let parts = timestamp.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]) else {
            return timestamp
        }
        return parts[2] == "1" ? "\(year)秋" : "\(year + 1)春"
    }

    private func termToTimestamp(_ term: String) -> String {
        guard let year = Int(term.dropLast()) else {
            return ""
        }
        if term.hasSuffix("秋") {
            return "\(year)-\(year + 1)-1"
        }
        return "\(year - 1)-\(year)-2"
    }

    private func scoreToGPA(_ score: Double) -> Double {
        switch score {
        case 95...100: return 4.3
        case 90..<95: return 4.0
        case 85..<90: return 3.7
        case 81..<85: return 3.3
        case 78..<81: return 3.0
        case 75..<78: return 2.7
        case 72..<75: return 2.3
        case 68..<72: return 2.0
        case 64..<68: return 1.7
        case 60..<64: return 1.0
        default: return 0
        }
    }
}
