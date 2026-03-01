import Foundation

struct CardInfo: Hashable {
    let account: String
    let name: String
    let studentNo: String
    let balance: Double
    let pendingAmount: Double
    let lostFlag: Bool
    let frozenFlag: Bool
    let expireDate: String
    let cardType: String
    let department: String
}

struct CardTransaction: Identifiable, Hashable {
    let id = UUID()
    let time: String
    let merchant: String
    let amount: Double
    let balance: Double
    let type: String
    let description: String
}

struct MerchantStat: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let totalAmount: Double
    let count: Int
}

struct MonthlyStats: Identifiable, Hashable {
    var id: String { month }
    let month: String
    let totalSpend: Double
    let totalIncome: Double
    let transactionCount: Int
    let topMerchants: [MerchantStat]
    let avgDailySpend: Double
    let peakDay: String
    let peakDayAmount: Double
}

struct MealTimeStats: Hashable {
    let count: Int
    let totalAmount: Double
    let avgAmount: Double
}

struct DayTypeStats: Hashable {
    let label: String
    let count: Int
    let totalAmount: Double
    let avgPerTransaction: Double
    let avgPerDay: Double
}

final class CampusCardAPI {
    private let login: CampusCardLogin
    private let baseURL = CampusCardLogin.baseURL

    init(login: CampusCardLogin) {
        self.login = login
    }

    func getCardInfo() async throws -> CardInfo {
        let response = try await login.client.post(
            "\(baseURL)/User/GetCardInfoByAccountNoParm",
            headers: ajaxHeaders,
            form: ["json": "true"]
        )

        let root = try jsonObject(response.data)
        let msg = root["Msg"] as? String ?? root["msg"] as? String ?? ""

        if msg == "-989" || msg == "989" {
            guard await login.reAuthenticate() else {
                throw HTTPError.authenticationRequired
            }
            return try await getCardInfo()
        }

        guard let msgData = msg.data(using: .utf8),
              let msgRoot = try? jsonObject(msgData),
              let query = msgRoot["query_card"] as? [String: Any],
              let cards = query["card"] as? [[String: Any]],
              let card = cards.first else {
            throw HTTPError.invalidResponse
        }

        let account = card.string("account")
        if login.cardAccount == nil, !account.isEmpty {
            login.cardAccount = account
        }

        return CardInfo(
            account: account,
            name: card.string("name"),
            studentNo: card.string("sno"),
            balance: card.double("elec_accamt") / 100,
            pendingAmount: card.double("unsettle_amount") / 100,
            lostFlag: card.string("lostflag") == "1",
            frozenFlag: card.string("freezeflag") == "1",
            expireDate: formatExpireDate(card.string("expdate")),
            cardType: card.string("cardname"),
            department: ""
        )
    }

    func getTransactions(
        startDate: Date,
        endDate: Date,
        page: Int = 1,
        pageSize: Int = 30
    ) async throws -> (total: Int, list: [CardTransaction]) {
        let account = login.cardAccount ?? ""

        let response = try await login.client.post(
            "\(baseURL)/Report/GetPersonTrjn",
            headers: ajaxHeaders,
            form: [
                "sdate": DateFormatter.ymd.string(from: startDate),
                "edate": DateFormatter.ymd.string(from: endDate),
                "account": account,
                "page": String(page),
                "rows": String(pageSize)
            ]
        )

        let root = try jsonObject(response.data)
        let total = root.int("total")
        let rows = root["rows"] as? [[String: Any]] ?? []

        let list = rows.map { row in
            CardTransaction(
                time: row.string("OCCTIME"),
                merchant: row.string("MERCNAME"),
                amount: row.double("TRANAMT"),
                balance: row.double("CARDBAL"),
                type: row.string("TRANNAME"),
                description: row.string("JDESC")
            )
        }

        return (total, list)
    }

    func getAllTransactions(
        startDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
        endDate: Date = Date(),
        maxPages: Int = 20
    ) async throws -> [CardTransaction] {
        let first = try await getTransactions(startDate: startDate, endDate: endDate, page: 1, pageSize: 50)
        if first.total <= 50 || first.list.isEmpty {
            return first.list
        }

        let totalPages = min((first.total + 49) / 50, maxPages)
        if totalPages <= 1 {
            return first.list
        }

        var all = first.list
        for page in 2...totalPages {
            if let result = try? await getTransactions(startDate: startDate, endDate: endDate, page: page, pageSize: 50) {
                all.append(contentsOf: result.list)
            }
        }

        return all
    }

    func calculateMonthlyStats(_ transactions: [CardTransaction]) -> [MonthlyStats] {
        let grouped = Dictionary(grouping: transactions) { tx -> String in
            String(tx.time.prefix(7))
        }

        return grouped.map { month, rows in
            let spend = rows.filter { $0.amount < 0 }
            let income = rows.filter { $0.amount > 0 }

            let merchantStats = Dictionary(grouping: spend, by: { $0.merchant })
                .map { merchant, txs in
                    MerchantStat(
                        name: merchant,
                        totalAmount: -txs.reduce(0) { $0 + $1.amount },
                        count: txs.count
                    )
                }
                .sorted { $0.totalAmount > $1.totalAmount }
                .prefix(10)

            let totalSpend = -spend.reduce(0) { $0 + $1.amount }
            let totalIncome = income.reduce(0) { $0 + $1.amount }
            let daySpend = Dictionary(grouping: spend, by: { String($0.time.prefix(10)) })
                .mapValues { -$0.reduce(0) { $0 + $1.amount } }
            let peak = daySpend.max { $0.value < $1.value }

            let avgDaily = daySpend.isEmpty ? 0 : totalSpend / Double(daySpend.count)

            return MonthlyStats(
                month: month,
                totalSpend: totalSpend,
                totalIncome: totalIncome,
                transactionCount: rows.count,
                topMerchants: Array(merchantStats),
                avgDailySpend: avgDaily,
                peakDay: peak?.key ?? "",
                peakDayAmount: peak?.value ?? 0
            )
        }.sorted { $0.month > $1.month }
    }

    func categorizeSpending(_ transactions: [CardTransaction]) -> [String: Double] {
        var categories: [String: Double] = [:]
        for tx in transactions where tx.amount < 0 {
            let category = classifyMerchant(merchant: tx.merchant, description: tx.description)
            categories[category, default: 0] += -tx.amount
        }
        return categories.sorted(by: { $0.value > $1.value }).reduce(into: [:]) { partial, entry in
            partial[entry.key] = entry.value
        }
    }

    func analyzeMealTimes(_ transactions: [CardTransaction]) -> [String: MealTimeStats] {
        var grouped: [String: [String: Double]] = [
            "早餐": [:],
            "午餐": [:],
            "晚餐": [:],
            "夜宵": [:]
        ]

        for tx in transactions where tx.amount < 0 {
            guard classifyMerchant(merchant: tx.merchant, description: tx.description) == "餐饮" else { continue }
            let hour = Int(tx.time.split(separator: " ").last?.prefix(2) ?? "") ?? 0
            let period: String
            switch hour {
            case 5...9: period = "早餐"
            case 10...14: period = "午餐"
            case 15...20: period = "晚餐"
            default: period = "夜宵"
            }

            let day = String(tx.time.prefix(10))
            grouped[period, default: [:]][day, default: 0] += -tx.amount
        }

        var result: [String: MealTimeStats] = [:]
        for (period, days) in grouped where !days.isEmpty {
            let count = days.count
            let total = days.values.reduce(0, +)
            result[period] = MealTimeStats(
                count: count,
                totalAmount: total,
                avgAmount: count > 0 ? total / Double(count) : 0
            )
        }
        return result
    }

    func analyzeWeekdayVsWeekend(_ transactions: [CardTransaction]) -> (weekday: DayTypeStats, weekend: DayTypeStats) {
        var weekdayAmounts: [Double] = []
        var weekendAmounts: [Double] = []
        var weekdayDays: Set<String> = []
        var weekendDays: Set<String> = []

        for tx in transactions where tx.amount < 0 {
            let dayString = String(tx.time.prefix(10))
            guard let date = DateFormatter.ymd.date(from: dayString) else { continue }
            let weekday = Calendar.current.component(.weekday, from: date)
            if (2...6).contains(weekday) {
                weekdayAmounts.append(-tx.amount)
                weekdayDays.insert(dayString)
            } else {
                weekendAmounts.append(-tx.amount)
                weekendDays.insert(dayString)
            }
        }

        return (
            dayTypeStats(label: "工作日", amounts: weekdayAmounts, dayCount: weekdayDays.count),
            dayTypeStats(label: "周末", amounts: weekendAmounts, dayCount: weekendDays.count)
        )
    }

    func dailySpending(_ transactions: [CardTransaction]) -> [String: Double] {
        Dictionary(grouping: transactions.filter { $0.amount < 0 }, by: { String($0.time.prefix(10)) })
            .mapValues { -$0.reduce(0) { $0 + $1.amount } }
    }

    private var ajaxHeaders: [String: String] {
        [
            "Accept": "application/json, text/javascript, */*; q=0.01",
            "X-Requested-With": "XMLHttpRequest",
            "Origin": baseURL,
            "Referer": "\(baseURL)/Page/Page"
        ]
    }

    private func classifyMerchant(merchant: String, description: String) -> String {
        let m = merchant.lowercased()
        let d = description.lowercased()

        if m.contains("浴") || m.contains("洗澡") {
            return "洗浴"
        }
        if m.contains("能源") || d.contains("电费") || d.contains("水费") {
            return "水电"
        }
        if m.contains("超市") || m.contains("便利") || m.contains("商店") {
            return "超市"
        }
        if m.contains("图书") || m.contains("打印") || m.contains("复印") {
            return "学习"
        }
        if m.contains("洗衣") {
            return "洗衣"
        }
        if m.contains("餐") || m.contains("面") || m.contains("饭") || m.contains("奶茶") {
            return "餐饮"
        }
        if d.contains("圈存") || d.contains("充值") || d.contains("转账") {
            return "充值"
        }
        return "其他"
    }

    private func dayTypeStats(label: String, amounts: [Double], dayCount: Int) -> DayTypeStats {
        let total = amounts.reduce(0, +)
        let count = amounts.count
        return DayTypeStats(
            label: label,
            count: count,
            totalAmount: total,
            avgPerTransaction: count > 0 ? total / Double(count) : 0,
            avgPerDay: dayCount > 0 ? total / Double(dayCount) : 0
        )
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        return dict
    }

    private func formatExpireDate(_ raw: String) -> String {
        guard raw.count == 8 else { return raw }
        let y = raw.prefix(4)
        let m = raw.dropFirst(4).prefix(2)
        let d = raw.suffix(2)
        return "\(y)-\(m)-\(d)"
    }
}
