import Foundation

enum FlowRecordType: Int, CaseIterable {
    case invalid = 0
    case valid = 1
    case repeated = 2
}

enum WaterType: Int, CaseIterable {
    case normal = 1
    case late = 2
    case absence = 3
    case leave = 5

    var displayName: String {
        switch self {
        case .normal: return "正常"
        case .late: return "迟到"
        case .absence: return "缺勤"
        case .leave: return "请假"
        }
    }
}

struct AttendanceFlow: Identifiable, Hashable {
    let id = UUID()
    let sbh: String
    let place: String
    let waterTime: String
    let type: FlowRecordType
}

struct AttendanceWaterRecord: Identifiable, Hashable {
    let id = UUID()
    let sbh: String
    let termString: String
    let startTime: Int
    let endTime: Int
    let week: Int
    let location: String
    let courseName: String
    let teacher: String
    let status: WaterType
    let date: String
}

struct TermInfo: Identifiable, Hashable {
    var id: String { bh }
    let bh: String
    let name: String
    let startDate: String
    let endDate: String
}

struct CourseAttendanceStat: Identifiable, Hashable {
    var id: String { subjectName + subjectCode }
    let subjectName: String
    let subjectCode: String
    let normalCount: Int
    let lateCount: Int
    let absenceCount: Int
    let leaveEarlyCount: Int
    let leaveCount: Int
    let total: Int

    var actualCount: Int { normalCount + leaveCount }
    var abnormalCount: Int { lateCount + absenceCount }
}

final class AttendanceAPI {
    private let login: AttendanceLogin
    private let baseURL = "http://bkkq.xjtu.edu.cn"

    init(login: AttendanceLogin) {
        self.login = login
    }

    func getStudentInfo() async throws -> [String: Any] {
        let json = try await post(path: "/attendance-student/global/getStuInfo")
        guard let data = json["data"] as? [String: Any] else {
            return [:]
        }

        return [
            "name": data["name"] as? String ?? "",
            "sno": (data["sno"] as? String) ?? (data["account"] as? String) ?? "",
            "identity": data["identity"] as? String ?? "",
            "campusName": data["campusName"] as? String ?? "",
            "departmentName": data["departmentName"] as? String ?? ""
        ]
    }

    func getTermBh() async throws -> String {
        let json = try await post(path: "/attendance-student/global/getNearTerm")
        let data = json["data"] as? [String: Any] ?? [:]
        return data["bh"] as? String ?? ""
    }

    func getTermList() async throws -> [TermInfo] {
        let json = try await post(path: "/attendance-student/global/getBeforeTodayTerm")
        let list = json["data"] as? [[String: Any]] ?? []

        return list.map { item in
            TermInfo(
                bh: item["bh"] as? String ?? "",
                name: item["name"] as? String ?? "",
                startDate: (item["startDate"] as? String) ?? (item["kssj"] as? String) ?? (item["startTime"] as? String) ?? "",
                endDate: (item["endDate"] as? String) ?? (item["jssj"] as? String) ?? (item["endTime"] as? String) ?? ""
            )
        }
    }

    func getFlowRecords(date: String? = nil) async throws -> [AttendanceFlow] {
        let targetDate = date ?? DateFormatter.ymd.string(from: Date())
        let body = [
            "startdate": targetDate,
            "enddate": targetDate,
            "current": 1,
            "pageSize": 200,
            "calendarBh": ""
        ] as [String: Any]

        let json = try await post(path: "/attendance-student/waterList/page", json: body)
        return parseFlowList(json)
    }

    func getFlowRecords(startDate: String, endDate: String) async throws -> [AttendanceFlow] {
        let body = [
            "startdate": startDate,
            "enddate": endDate,
            "current": 1,
            "pageSize": 200,
            "calendarBh": ""
        ] as [String: Any]

        let json = try await post(path: "/attendance-student/waterList/page", json: body)
        return parseFlowList(json)
    }

    func getWaterRecords(termBh: String? = nil) async throws -> [AttendanceWaterRecord] {
        let bh: String
        if let termBh {
            bh = termBh
        } else {
            bh = try await getTermBh()
        }
        let body = [
            "startDate": "",
            "endDate": "",
            "current": 1,
            "pageSize": 500,
            "timeCondition": "",
            "subjectBean": ["sCode": ""],
            "classWaterBean": ["status": ""],
            "classBean": ["termNo": bh]
        ] as [String: Any]

        let json = try await post(path: "/attendance-student/classWater/getClassWaterPage", json: body)
        let list = ((json["data"] as? [String: Any])?["list"] as? [[String: Any]]) ?? []

        return list.map { item in
            let classWater = item["classWaterBean"] as? [String: Any] ?? [:]
            let account = item["accountBean"] as? [String: Any] ?? [:]
            let build = item["buildBean"] as? [String: Any] ?? [:]
            let room = item["roomBean"] as? [String: Any] ?? [:]
            let calendar = item["calendarBean"] as? [String: Any] ?? [:]
            let subject = item["subjectBean"] as? [String: Any] ?? [:]

            let statusValue = int(classWater["status"], default: 1)

            return AttendanceWaterRecord(
                sbh: classWater["bh"] as? String ?? "",
                termString: calendar["name"] as? String ?? "",
                startTime: int(account["startJc"], default: 0),
                endTime: int(account["endJc"], default: 0),
                week: int(account["week"], default: 0),
                location: "\(build["name"] as? String ?? "")-\(room["roomnum"] as? String ?? "")",
                courseName: (subject["sName"] as? String) ?? (subject["subjectname"] as? String) ?? "",
                teacher: item["teachNameList"] as? String ?? "",
                status: WaterType(rawValue: statusValue) ?? .normal,
                date: account["checkdate"] as? String ?? ""
            )
        }
    }

    func getCurrentWeekStats() async throws -> [CourseAttendanceStat] {
        let json = try await post(path: "/attendance-student/kqtj/getKqtjCurrentWeek")
        return parseCourseStats(json)
    }

    func getStats(startDate: String, endDate: String) async throws -> [CourseAttendanceStat] {
        let body = [
            "startDate": startDate,
            "endDate": "\(endDate) 23:59:59"
        ]
        let json = try await post(path: "/attendance-student/kqtj/getKqtjByTime", json: body)
        return parseCourseStats(json)
    }

    func computeCourseStats(from records: [AttendanceWaterRecord]) -> [CourseAttendanceStat] {
        Dictionary(grouping: records, by: { $0.courseName })
            .filter { !$0.key.isEmpty }
            .map { name, rows in
                CourseAttendanceStat(
                    subjectName: name,
                    subjectCode: "",
                    normalCount: rows.filter { $0.status == .normal }.count,
                    lateCount: rows.filter { $0.status == .late }.count,
                    absenceCount: rows.filter { $0.status == .absence }.count,
                    leaveEarlyCount: 0,
                    leaveCount: rows.filter { $0.status == .leave }.count,
                    total: rows.count
                )
            }
    }

    private func post(path: String, json: [String: Any]? = nil) async throws -> [String: Any] {
        let url = "\(baseURL)\(path)"

        let response: HTTPResponse
        if let json {
            let body = try JSONSerialization.data(withJSONObject: json)
            response = try await login.executeWithReAuth(
                url: url,
                method: "POST",
                body: body,
                contentType: "application/json"
            )
        } else {
            response = try await login.executeWithReAuth(
                url: url,
                method: "POST",
                body: Data(),
                contentType: nil
            )
        }

        let object = try JSONSerialization.jsonObject(with: response.data)
        guard let dict = object as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        return dict
    }

    private func parseFlowList(_ json: [String: Any]) -> [AttendanceFlow] {
        let list = ((json["data"] as? [String: Any])?["list"] as? [[String: Any]]) ?? []
        return list.map { item in
            let typeValue = int(item["isdone"], default: 0)
            return AttendanceFlow(
                sbh: item["sBh"] as? String ?? "",
                place: item["eqno"] as? String ?? "",
                waterTime: item["watertime"] as? String ?? "",
                type: FlowRecordType(rawValue: typeValue) ?? .invalid
            )
        }
    }

    private func parseCourseStats(_ json: [String: Any]) -> [CourseAttendanceStat] {
        let list = json["data"] as? [[String: Any]] ?? []
        return list.compactMap { item in
            guard let name = item["subjectname"] as? String else {
                return nil
            }
            return CourseAttendanceStat(
                subjectName: name,
                subjectCode: item["subjectCode"] as? String ?? "",
                normalCount: int(item["normalCount"], default: 0),
                lateCount: int(item["lateCount"], default: 0),
                absenceCount: int(item["absenceCount"], default: 0),
                leaveEarlyCount: int(item["leaveEarlyCount"], default: 0),
                leaveCount: int(item["leaveCount"], default: 0),
                total: int(item["total"], default: 0)
            )
        }
    }

    private func int(_ value: Any?, default defaultValue: Int) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value) ?? defaultValue }
        return defaultValue
    }
}
