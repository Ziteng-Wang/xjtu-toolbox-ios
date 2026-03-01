import Foundation

enum ScoreSource: String, Codable {
    case jwapp
    case report
}

struct ScoreItem: Identifiable, Hashable {
    let id: String
    let termCode: String
    let courseName: String
    let score: String
    let scoreValue: Double?
    let passFlag: Bool
    let specificReason: String?
    let coursePoint: Double
    let examType: String
    let majorFlag: String?
    let examProp: String
    let replaceFlag: Bool
    let gpa: Double?
    let source: ScoreSource
}

struct ScoreDetailItem: Identifiable, Hashable {
    let id = UUID()
    let itemName: String
    let itemPercent: Double
    let itemScore: String
    let itemScoreValue: Double?
}

struct ScoreDetail: Hashable {
    let courseName: String
    let coursePoint: Double
    let examType: String
    let majorFlag: String?
    let examProp: String
    let replaceFlag: Bool
    let score: String
    let scoreValue: Double?
    let gpa: Double
    let passFlag: Bool
    let specificReason: String?
    let itemList: [ScoreDetailItem]
}

struct TermScore: Identifiable, Hashable {
    var id: String { termCode }
    let termCode: String
    let termName: String
    let scoreList: [ScoreItem]
}

struct ScoreDistRange: Identifiable, Hashable {
    var id: String { range }
    let range: String
    let num: Int
}

struct ScoreRank: Hashable {
    let defeatPercent: Double?
    let scoreHigh: Double?
    let scoreAvg: Double?
    let scoreLow: Double?
    let scoreDist: [ScoreDistRange]
}

struct TimeTableBasis: Hashable {
    let termCode: String
    let termName: String
    let maxWeekNum: Int
    let maxSection: Int
    let todayWeekDay: Int
    let todayWeekNum: Int
}

struct GPAInfo: Hashable {
    let gpa: Double
    let averageScore: Double
    let totalCredits: Double
    let courseCount: Int
}

func gradeToNumericScore(_ rawGrade: String) -> Double? {
    let grade = rawGrade
        .replacingOccurrences(of: "＋", with: "+")
        .replacingOccurrences(of: "－", with: "-")
        .removingInvisibleCharacters
        .uppercased()

    switch grade {
    case "A+", "优+": return 98
    case "A", "优": return 92
    case "A-", "优-": return 87
    case "B+", "良+": return 83
    case "B", "良": return 79
    case "B-", "良-": return 76
    case "C+", "中+": return 73
    case "C", "中": return 70
    case "C-", "中-": return 66
    case "D", "及格": return 62
    case "F", "不及格": return 0
    case "通过", "不通过": return nil
    default:
        return Double(grade)
    }
}

final class JWAppAPI {
    private let login: JwappLogin
    private let baseURL = "http://jwapp.xjtu.edu.cn"

    init(login: JwappLogin) {
        self.login = login
    }

    func getGrade(termCode: String? = nil) async throws -> [TermScore] {
        let response = try await login.executeWithReAuth(
            url: "\(baseURL)/api/biz/v410/score/termScore",
            method: "POST",
            json: ["termCode": termCode ?? "*"]
        )

        let root = try jsonObject(response.data)
        try assertCode200(root)

        let data = root["data"] as? [String: Any] ?? [:]
        let list = data["termScoreList"] as? [[String: Any]] ?? []

        return list.map { term in
            let scoreList = (term["scoreList"] as? [[String: Any]] ?? []).map { item in
                let score = item["score"] as? String ?? ""
                return ScoreItem(
                    id: item.string("id"),
                    termCode: item.string("termCode"),
                    courseName: item.string("courseName"),
                    score: score,
                    scoreValue: Double(score),
                    passFlag: item.bool("passFlag"),
                    specificReason: item["specificReason"] as? String,
                    coursePoint: item.double("coursePoint"),
                    examType: item.string("examType"),
                    majorFlag: item["majorFlag"] as? String,
                    examProp: item.string("examProp"),
                    replaceFlag: item.bool("replaceFlag"),
                    gpa: item["gpa"] as? Double,
                    source: .jwapp
                )
            }

            return TermScore(
                termCode: term.string("termCode"),
                termName: term.string("termName"),
                scoreList: scoreList
            )
        }
    }

    func getDetail(courseID: String) async throws -> ScoreDetail {
        let response = try await login.executeWithReAuth(
            url: "\(baseURL)/api/biz/v410/score/scoreDetail",
            method: "POST",
            json: ["id": courseID]
        )

        let root = try jsonObject(response.data)
        try assertCode200(root)

        let data = root["data"] as? [String: Any] ?? [:]
        let score = data.string("score")
        let serverGPA = data.double("gpa")
        let effectiveGPA = serverGPA > 0 ? serverGPA : (ScoreReportAPI.scoreToGPA(score) ?? 0)

        let itemList = (data["itemList"] as? [[String: Any]] ?? []).map { item in
            let percentRaw = item.string("itemPercent")
            let percentValue = Double(percentRaw.replacingOccurrences(of: "%", with: "")) ?? 0
            return ScoreDetailItem(
                itemName: item.string("itemName"),
                itemPercent: percentValue / 100,
                itemScore: item.string("itemScore"),
                itemScoreValue: Double(item.string("itemScore"))
            )
        }

        return ScoreDetail(
            courseName: data.string("courseName"),
            coursePoint: data.double("coursePoint"),
            examType: data.string("examType"),
            majorFlag: data["majorFlag"] as? String,
            examProp: data.string("examProp"),
            replaceFlag: data.bool("replaceFlag"),
            score: score,
            scoreValue: Double(score),
            gpa: effectiveGPA,
            passFlag: data.bool("passFlag"),
            specificReason: data["specificReason"] as? String,
            itemList: itemList
        )
    }

    func getRank(courseID: String) async throws -> ScoreRank {
        let response = try await login.executeWithReAuth(
            url: "\(baseURL)/api/biz/v410/score/scoreAnalyze",
            method: "POST",
            json: ["id": courseID]
        )

        let root = try jsonObject(response.data)
        try assertCode200(root)

        let data = root["data"] as? [String: Any] ?? [:]
        let dist = (data["scoreDist"] as? [[String: Any]] ?? []).map {
            ScoreDistRange(range: $0.string("range"), num: $0.int("num"))
        }

        return ScoreRank(
            defeatPercent: data["defeatPercent"] as? Double,
            scoreHigh: data["scoreHigh"] as? Double,
            scoreAvg: data["scoreAvg"] as? Double,
            scoreLow: data["scoreLow"] as? Double,
            scoreDist: dist
        )
    }

    func getTimeTableBasis() async throws -> TimeTableBasis {
        let response = try await login.executeWithReAuth(
            url: "https://jwapp.xjtu.edu.cn/api/biz/v410/common/school/time"
        )

        let root = try jsonObject(response.data)
        try assertCode200(root)

        let data = (root["data"] as? [String: Any]) ?? root

        return TimeTableBasis(
            termCode: data.string("xnxqdm"),
            termName: data.string("xnxqmc"),
            maxWeekNum: data.int("maxWeekNum"),
            maxSection: data.int("maxSection"),
            todayWeekDay: data.int("todayWeekDay"),
            todayWeekNum: data.int("todayWeekNum")
        )
    }

    func getCurrentTerm() async throws -> String {
        try await getTimeTableBasis().termCode
    }

    func getCurrentWeek() async throws -> Int {
        try await getTimeTableBasis().todayWeekNum
    }

    func calculateGPA(from termScores: [TermScore]) -> GPAInfo {
        calculateGPA(for: termScores.flatMap { $0.scoreList })
    }

    func calculateGPA(for courses: [ScoreItem]) -> GPAInfo {
        var totalCredits = 0.0
        var weightedGPA = 0.0
        var weightedScore = 0.0
        var courseCount = 0

        for course in courses {
            let clean = course.score
                .replacingOccurrences(of: "＋", with: "+")
                .replacingOccurrences(of: "－", with: "-")
                .removingInvisibleCharacters

            if clean == "通过" || clean == "不通过" {
                continue
            }

            let apiGPA = (course.gpa ?? 0) > 0 ? course.gpa! : 0
            let mappedGPA = ScoreReportAPI.scoreToGPA(clean) ?? apiGPA
            let finalGPA = max(apiGPA, mappedGPA)
            let numericScore = course.scoreValue ?? gradeToNumericScore(course.score) ?? 0

            let passed = course.passFlag || finalGPA > 0 || numericScore >= 60
            if !passed && course.examProp == "初修" {
                continue
            }

            totalCredits += course.coursePoint
            weightedGPA += finalGPA * course.coursePoint
            weightedScore += numericScore * course.coursePoint
            courseCount += 1
        }

        let gpa = totalCredits > 0 ? weightedGPA / totalCredits : 0
        let average = totalCredits > 0 ? weightedScore / totalCredits : 0

        return GPAInfo(
            gpa: gpa,
            averageScore: average,
            totalCredits: totalCredits,
            courseCount: courseCount
        )
    }

    private func assertCode200(_ root: [String: Any]) throws {
        let code: Int
        if let int = root["code"] as? Int {
            code = int
        } else if let string = root["code"] as? String {
            code = Int(string) ?? -1
        } else {
            code = -1
        }

        guard code == 200 else {
            let msg = root["msg"] as? String ?? "服务错误"
            throw HTTPError.serverError(status: code, message: msg)
        }
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let result = object as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        return result
    }
}
