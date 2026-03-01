import SwiftUI

struct CampusCardScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var cardInfo: CardInfo?
    @State private var transactions: [CardTransaction] = []
    @State private var monthlyStats: [MonthlyStats] = []
    @State private var message = ""

    var body: some View {
        List {
            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            if let cardInfo {
                Section("校园卡") {
                    row("姓名", cardInfo.name)
                    row("学号", cardInfo.studentNo)
                    row("账号", cardInfo.account)
                    row("余额", String(format: "%.2f 元", cardInfo.balance))
                    row("待入账", String(format: "%.2f 元", cardInfo.pendingAmount))
                    row("有效期", cardInfo.expireDate)
                    row("卡类型", cardInfo.cardType)
                }
            }

            Section("近期开销") {
                if monthlyStats.isEmpty {
                    Text("暂无统计")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(monthlyStats) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.month)
                                .font(.headline)
                            Text("支出 \(String(format: "%.2f", item.totalSpend)) · 收入 \(String(format: "%.2f", item.totalIncome))")
                                .font(.subheadline)
                            Text("日均 \(String(format: "%.2f", item.avgDailySpend)) · 交易 \(item.transactionCount)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("最近交易") {
                if transactions.isEmpty {
                    Text("暂无交易")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(transactions.prefix(30)) { tx in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tx.merchant.isEmpty ? tx.type : tx.merchant)
                                    .font(.headline)
                                Text(tx.time)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String(format: "%.2f", tx.amount))
                                    .foregroundStyle(tx.amount < 0 ? .red : .green)
                                Text(String(format: "余额 %.2f", tx.balance))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("校园卡")
        .refreshable { await loadData() }
        .task {
            if cardInfo == nil {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard await loginState.ensureLogin(type: .campusCard),
              let login = loginState.campusCardLogin else {
            message = "未登录校园卡系统"
            return
        }

        do {
            let api = CampusCardAPI(login: login)
            let info = try await api.getCardInfo()
            let allTransactions = try await api.getAllTransactions()

            cardInfo = info
            transactions = allTransactions
            monthlyStats = api.calculateMonthlyStats(allTransactions)
            message = ""
        } catch {
            message = error.localizedDescription
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
