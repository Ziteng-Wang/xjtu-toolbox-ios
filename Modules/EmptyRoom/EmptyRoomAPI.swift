import Foundation

struct RoomInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let size: Int
    let status: [Int]
}

enum EmptyRoomError: Error, LocalizedError {
    case noData(String)

    var errorDescription: String? {
        switch self {
        case let .noData(message):
            return message
        }
    }
}

let campusBuildings: [String: [String]] = [
    "兴庆校区": ["主楼A", "主楼B", "主楼C", "主楼D", "中一", "中二", "西一", "西二", "外文楼A", "外文楼B", "东一", "东二", "仁英楼", "东西", "教二楼", "主楼E", "工程坊", "文管", "计教中心"],
    "雁塔校区": ["东配楼", "微免楼", "综合楼", "教学楼", "药学楼", "解剖楼", "生化楼", "病理楼", "西配楼", "一附院科教楼", "二院教学楼"],
    "曲江校区": ["西一楼", "西五楼", "西四楼", "西六楼"],
    "创新港校区": ["1", "2", "3", "4", "5", "9", "18", "19", "20", "21"],
    "苏州校区": ["公共学院5号楼"]
]

final class EmptyRoomAPI {
    private let baseURL = "https://gh-release.xjtutoolbox.com/"
    private let client: HTTPClient

    private var cachedDate: String?
    private var cachedData: [String: Any]?

    init(client: HTTPClient = .shared) {
        self.client = client
    }

    func getEmptyRooms(
        campusName: String,
        buildingName: String,
        date: String = DateFormatter.ymd.string(from: Date())
    ) async throws -> [RoomInfo] {
        let data = try await fetchDayData(date: date)

        guard let campus = data[campusName] as? [String: Any] else {
            throw EmptyRoomError.noData("暂无 \(campusName) 数据")
        }
        guard let building = campus[buildingName] as? [String: Any] else {
            throw EmptyRoomError.noData("暂无 \(campusName)-\(buildingName) 数据")
        }

        let rooms = building.compactMap { key, value -> RoomInfo? in
            guard key != "null", !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let object = value as? [String: Any] else {
                return nil
            }

            let status = (object["status"] as? [Int]) ?? []
            let size = object["size"] as? Int ?? 0

            return RoomInfo(name: key, size: size, status: status)
        }

        return rooms.sorted { $0.name < $1.name }
    }

    func getAvailableDates() -> [String] {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        return [DateFormatter.ymd.string(from: today), DateFormatter.ymd.string(from: tomorrow)]
    }

    private func fetchDayData(date: String) async throws -> [String: Any] {
        if cachedDate == date, let cachedData {
            return cachedData
        }

        let url = "\(baseURL)?file=static/empty_room/\(date).json"
        let response = try await client.get(url)

        if response.http.statusCode == 404 {
            throw EmptyRoomError.noData("当天暂无空教室数据")
        }

        guard response.http.statusCode == 200 else {
            throw HTTPError.serverError(status: response.http.statusCode, message: "获取空教室失败")
        }

        let object = try JSONSerialization.jsonObject(with: response.data)
        guard let dict = object as? [String: Any] else {
            throw HTTPError.invalidResponse
        }

        cachedDate = date
        cachedData = dict
        return dict
    }
}
