import Foundation

struct UserInfo: Codable {
    let userName: String
    let userUid: String
    let identityTypeName: String
    let organizationName: String
}

final class YWTBAPI {
    private let login: YwtbLogin

    init(login: YwtbLogin) {
        self.login = login
    }

    func getUserInfo() async throws -> UserInfo {
        let response = try await login.executeWithReAuth(
            url: "https://authx-service.xjtu.edu.cn/personal/api/v1/personal/me/user"
        )

        guard let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            throw HTTPError.invalidResponse
        }

        if response.http.statusCode != 200 {
            let message = (json["message"] as? String) ?? "服务错误"
            throw HTTPError.serverError(status: response.http.statusCode, message: message)
        }

        let data = json["data"] as? [String: Any] ?? [:]
        let attributes = data["attributes"] as? [String: Any] ?? [:]

        return UserInfo(
            userName: (attributes["userName"] as? String) ?? (data["username"] as? String) ?? "",
            userUid: (attributes["userUid"] as? String) ?? "",
            identityTypeName: (attributes["identityTypeName"] as? String) ?? "",
            organizationName: (attributes["organizationName"] as? String) ?? ""
        )
    }

    func getCurrentWeekOfTeaching() async throws -> (week: Int, semesterName: String, semesterID: String)? {
        let today = DateFormatter.ymd.string(from: Date())
        guard let base = URL(string: "https://ywtb.xjtu.edu.cn/portal-api/v1/calendar/share/schedule/getWeekOfTeaching") else {
            throw HTTPError.invalidURL
        }

        let url = base.appendingQuery([
            URLQueryItem(name: "today", value: today),
            URLQueryItem(name: "random_number", value: String(Int.random(in: 100...999)))
        ])

        let response = try await login.executeWithReAuth(url: url.absoluteString)
        guard let root = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let data = root["data"] as? [String: Any],
              let nested = data["data"] as? [String: Any],
              let weekValues = nested["date"] as? [String],
              let weekValue = weekValues.first,
              let week = Int(weekValue),
              week > 0 else {
            return nil
        }

        let semesterName = (nested["semesterAlilist"] as? [String])?.first ?? ""
        let semesterID = (nested["semesterlist"] as? [String])?.first ?? ""

        return (week, semesterName, semesterID)
    }

    func getStartOfTerm(timestamp: String) async throws -> String {
        let parts = timestamp.split(separator: "-")
        guard parts.count == 3 else {
            throw HTTPError.serverError(status: 0, message: "时间戳格式应为 YYYY-YYYY-S")
        }

        let startYear = String(parts[0])
        let endYear = String(parts[1])
        let term = String(parts[2])

        let possibleStarts: [String]
        let expectedSemester: String

        if term == "1" {
            expectedSemester = "第一学期"
            possibleStarts = stride(from: 1, through: 30, by: 7).map { day in
                String(format: "%@-08-%02d", startYear, day)
            } + stride(from: 1, through: 30, by: 7).map { day in
                String(format: "%@-09-%02d", startYear, day)
            }
        } else {
            expectedSemester = "第二学期"
            possibleStarts = stride(from: 1, through: 28, by: 7).map { day in
                String(format: "%@-02-%02d", endYear, day)
            } + stride(from: 1, through: 30, by: 7).map { day in
                String(format: "%@-03-%02d", endYear, day)
            }
        }

        guard let base = URL(string: "https://ywtb.xjtu.edu.cn/portal-api/v1/calendar/share/schedule/getWeekOfTeaching") else {
            throw HTTPError.invalidURL
        }

        let url = base.appendingQuery([
            URLQueryItem(name: "today", value: possibleStarts.joined(separator: ",")),
            URLQueryItem(name: "random_number", value: String(Int.random(in: 100...999)))
        ])

        let response = try await login.executeWithReAuth(url: url.absoluteString)
        guard let root = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let data = root["data"] as? [String: Any],
              let nested = data["data"] as? [String: Any],
              let weekList = nested["date"] as? [String],
              let semesterAliases = nested["semesterAlilist"] as? [String],
              let semesterIDs = nested["semesterlist"] as? [String] else {
            throw HTTPError.invalidResponse
        }

        for index in 0..<min(weekList.count, possibleStarts.count) {
            let week = weekList[index]
            let semesterName = semesterAliases[safe: index] ?? ""
            let semesterID = semesterIDs[safe: index] ?? ""

            if semesterID == "\(startYear)-\(endYear)", semesterName == expectedSemester, week == "1" {
                guard let date = DateFormatter.ymd.date(from: possibleStarts[index]) else {
                    continue
                }
                let calendar = Calendar(identifier: .gregorian)
                let weekday = calendar.component(.weekday, from: date)
                let offset = (weekday + 5) % 7
                guard let monday = calendar.date(byAdding: .day, value: -offset, to: date) else {
                    continue
                }
                return DateFormatter.ymd.string(from: monday)
            }
        }

        throw HTTPError.serverError(status: 0, message: "无法确定学期开始时间")
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
