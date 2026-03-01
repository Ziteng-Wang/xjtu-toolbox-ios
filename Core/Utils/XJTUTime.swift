import Foundation

struct XJTUClassTime: Hashable {
    let start: String
    let end: String
    let attendanceStart: String
    let attendanceEnd: String
}

enum XJTUTime {
    static func isSummer(month: Int = Calendar.current.component(.month, from: Date())) -> Bool {
        (5...9).contains(month)
    }

    private static let winter: [Int: XJTUClassTime] = [
        1: .init(start: "08:00", end: "08:50", attendanceStart: "07:20", attendanceEnd: "08:05"),
        2: .init(start: "09:00", end: "09:50", attendanceStart: "08:20", attendanceEnd: "09:05"),
        3: .init(start: "10:10", end: "11:00", attendanceStart: "09:35", attendanceEnd: "10:15"),
        4: .init(start: "11:10", end: "12:00", attendanceStart: "10:35", attendanceEnd: "11:15"),
        5: .init(start: "14:00", end: "14:50", attendanceStart: "13:20", attendanceEnd: "14:05"),
        6: .init(start: "15:00", end: "15:50", attendanceStart: "14:20", attendanceEnd: "15:05"),
        7: .init(start: "16:10", end: "17:00", attendanceStart: "15:35", attendanceEnd: "16:15"),
        8: .init(start: "17:10", end: "18:00", attendanceStart: "16:35", attendanceEnd: "17:15"),
        9: .init(start: "19:10", end: "20:00", attendanceStart: "18:30", attendanceEnd: "19:15"),
        10: .init(start: "20:10", end: "21:00", attendanceStart: "19:35", attendanceEnd: "20:15"),
        11: .init(start: "21:10", end: "22:00", attendanceStart: "20:35", attendanceEnd: "21:15")
    ]

    private static let summer: [Int: XJTUClassTime] = [
        1: .init(start: "08:00", end: "08:50", attendanceStart: "07:20", attendanceEnd: "08:05"),
        2: .init(start: "09:00", end: "09:50", attendanceStart: "08:20", attendanceEnd: "09:05"),
        3: .init(start: "10:10", end: "11:00", attendanceStart: "09:35", attendanceEnd: "10:15"),
        4: .init(start: "11:10", end: "12:00", attendanceStart: "10:35", attendanceEnd: "11:15"),
        5: .init(start: "14:30", end: "15:20", attendanceStart: "13:50", attendanceEnd: "14:35"),
        6: .init(start: "15:30", end: "16:20", attendanceStart: "14:50", attendanceEnd: "15:35"),
        7: .init(start: "16:40", end: "17:30", attendanceStart: "16:05", attendanceEnd: "16:45"),
        8: .init(start: "17:40", end: "18:30", attendanceStart: "17:05", attendanceEnd: "17:45"),
        9: .init(start: "19:40", end: "20:30", attendanceStart: "19:00", attendanceEnd: "19:45"),
        10: .init(start: "20:40", end: "21:30", attendanceStart: "20:05", attendanceEnd: "20:45"),
        11: .init(start: "21:40", end: "22:30", attendanceStart: "21:05", attendanceEnd: "21:45")
    ]

    static func classTime(section: Int, summerTerm: Bool = isSummer()) -> XJTUClassTime? {
        (summerTerm ? summer : winter)[section]
    }

    static func allTimes(summerTerm: Bool = isSummer()) -> [(Int, XJTUClassTime)] {
        let schedule = summerTerm ? summer : winter
        return schedule.keys.sorted().compactMap { section in
            guard let time = schedule[section] else { return nil }
            return (section, time)
        }
    }
}
