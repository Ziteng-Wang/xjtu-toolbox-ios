import SwiftUI
import UIKit

private enum CampusCardTab: String, CaseIterable, Identifiable {
    case overview = "概览"
    case transactions = "流水"
    case analytics = "分析"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview:
            return "square.grid.2x2"
        case .transactions:
            return "list.bullet.rectangle"
        case .analytics:
            return "chart.bar.xaxis"
        }
    }
}

private enum CampusCardTimeRange: String, CaseIterable, Identifiable {
    case oneMonth = "1个月"
    case threeMonths = "3个月"
    case sixMonths = "半年"
    case oneYear = "1年"

    var id: String { rawValue }

    var months: Int {
        switch self {
        case .oneMonth:
            return 1
        case .threeMonths:
            return 3
        case .sixMonths:
            return 6
        case .oneYear:
            return 12
        }
    }
}

private struct TransactionGroup: Identifiable {
    let date: String
    let items: [CardTransaction]

    var id: String { date }
}

struct CampusCardScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var message = ""

    @State private var selectedTab: CampusCardTab = .overview
    @State private var selectedTimeRange: CampusCardTimeRange = .oneMonth
    @State private var searchQuery = ""

    @State private var cardInfo: CardInfo?
    @State private var transactions: [CardTransaction] = []
    @State private var monthlyStats: [MonthlyStats] = []
    @State private var categorySpending: [String: Double] = [:]
    @State private var mealTimeStats: [String: MealTimeStats] = [:]
    @State private var weekdayWeekend: (weekday: DayTypeStats, weekend: DayTypeStats)?

    var body: some View {
        Group {
            if isLoading && !hasLoaded {
                loadingView
            } else if !hasLoaded && !message.isEmpty {
                errorView
            } else {
                contentView
            }
        }
        .navigationTitle("校园卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadData(range: selectedTimeRange) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            guard !hasLoaded else { return }
            await loadData(range: selectedTimeRange)
        }
    }

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                tabSelector

                if !message.isEmpty {
                    messageBanner
                }

                switch selectedTab {
                case .overview:
                    overviewTab
                case .transactions:
                    transactionTab
                case .analytics:
                    analyticsTab
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollIndicators(.hidden)
        .refreshable {
            await loadData(range: selectedTimeRange)
        }
        .overlay {
            if isLoading && hasLoaded {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.thinMaterial)
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在刷新校园卡数据...")
                            .font(.footnote)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .frame(width: 190, height: 52)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("正在加载校园卡数据...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await loadData(range: selectedTimeRange) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(CampusCardTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                            .font(.caption.weight(.semibold))
                        Text(tab.rawValue)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedTab == tab ? Color.blue : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedTab == tab ? Color.blue.opacity(0.14) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var messageBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
    }

    private var overviewTab: some View {
        VStack(spacing: 12) {
            if let cardInfo {
                balanceCard(cardInfo)
                statusCard(cardInfo)
            } else {
                missingDataCard("暂无校园卡信息")
            }

            monthlyOverviewCard

            if !mealTimeStats.isEmpty {
                mealQuickViewCard
            }

            recentTransactionsCard
        }
    }

    private func balanceCard(_ info: CardInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("校园卡余额")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.82))
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("¥")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(currency(info.balance, digits: 2, withSymbol: false))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    if info.pendingAmount > 0 {
                        Text("待入账 \(currency(info.pendingAmount))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                    Image(systemName: "creditcard.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
            }

            HStack(spacing: 8) {
                infoTag(info.name)
                infoTag(info.cardType)
                if !info.account.isEmpty {
                    infoTag("一卡通 \(info.account)")
                }
            }

            if !info.expireDate.isEmpty || !info.studentNo.isEmpty {
                HStack(spacing: 16) {
                    if !info.studentNo.isEmpty {
                        tinyInfo(label: "学号", value: info.studentNo)
                    }
                    if !info.expireDate.isEmpty {
                        tinyInfo(label: "有效期", value: info.expireDate)
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func infoTag(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.86))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.18), in: Capsule())
    }

    private func tinyInfo(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func statusCard(_ info: CardInfo) -> some View {
        HStack(spacing: 10) {
            statusPill(
                title: info.lostFlag ? "已挂失" : "卡片正常",
                symbol: info.lostFlag ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                color: info.lostFlag ? .orange : .green
            )
            statusPill(
                title: info.frozenFlag ? "已冻结" : "未冻结",
                symbol: info.frozenFlag ? "lock.fill" : "lock.open.fill",
                color: info.frozenFlag ? .red : .blue
            )
        }
    }

    private func statusPill(title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var monthlyOverviewCard: some View {
        let current = currentMonthStats
        let previous = previousMonthStats
        let diff = monthDiff(current: current, previous: previous)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本月消费")
                        .font(.headline)
                    Text(current?.month ?? "暂无数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let diff {
                    HStack(spacing: 4) {
                        Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2.weight(.bold))
                        Text("\(abs(diff), specifier: "%.0f")%")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(diff >= 0 ? Color.red : Color.green)
                    .background(
                        (diff >= 0 ? Color.red : Color.green).opacity(0.12),
                        in: Capsule()
                    )
                }
            }

            HStack(spacing: 10) {
                metricBox(title: "支出", value: currency(current?.totalSpend ?? 0), color: .red)
                metricBox(title: "收入", value: currency(current?.totalIncome ?? 0), color: .green)
            }

            HStack(spacing: 10) {
                metricBox(title: "交易笔数", value: "\(current?.transactionCount ?? 0)", color: .blue)
                metricBox(title: "日均消费", value: currency(current?.avgDailySpend ?? 0), color: .indigo)
            }

            if let peakDay = current?.peakDay, !peakDay.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("峰值消费日 \(friendlyDate(peakDay)): \(currency(current?.peakDayAmount ?? 0))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func metricBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }

    private var mealQuickViewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("用餐概览", symbol: "fork.knife")
            HStack(spacing: 10) {
                ForEach(["早餐", "午餐", "晚餐", "夜宵"], id: \.self) { period in
                    let stats = mealTimeStats[period]
                    VStack(spacing: 4) {
                        Image(systemName: mealIcon(for: period))
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Text(period)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(currency(stats?.avgAmount ?? 0))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(stats?.count ?? 0)天")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("最近交易", symbol: "clock.arrow.circlepath")

            if transactions.isEmpty {
                missingDataCard("当前时间段暂无交易")
            } else {
                ForEach(Array(transactions.prefix(5).enumerated()), id: \.offset) { _, tx in
                    transactionRow(tx)
                }
            }
        }
    }

    private var transactionTab: some View {
        VStack(spacing: 12) {
            timeRangeSelector

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索商户 / 类型 / 描述", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )

            HStack {
                Text(searchQuery.isEmpty ? "共 \(transactions.count) 笔" : "匹配 \(filteredTransactions.count) 笔")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("支出 \(currency(filteredTotalSpend)) · 收入 \(currency(filteredTotalIncome))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if filteredTransactions.isEmpty {
                missingDataCard(searchQuery.isEmpty ? "暂无交易记录" : "未找到匹配交易")
            } else {
                ForEach(groupedTransactions) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(friendlyDate(group.date))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("支出 \(currency(daySpend(group.items)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(group.items) { tx in
                            transactionRow(tx)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                }
            }
        }
    }

    private func transactionRow(_ tx: CardTransaction) -> some View {
        let isExpense = tx.amount < 0
        let color: Color = isExpense ? .red : .green
        let merchant = tx.merchant.isEmpty ? (tx.type.isEmpty ? "未知交易" : tx.type) : tx.merchant

        return HStack(spacing: 10) {
            Image(systemName: transactionIcon(for: tx))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(merchant)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(shortTime(tx.time))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text((isExpense ? "-" : "+") + currency(abs(tx.amount), withSymbol: false))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Text("余额 \(currency(tx.balance))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
    }

    private var analyticsTab: some View {
        VStack(spacing: 12) {
            timeRangeSelector

            if categorySpending.isEmpty && monthlyStats.isEmpty && mealTimeStats.isEmpty {
                missingDataCard("当前时间范围暂无可分析数据")
            } else {
                if !categorySpending.isEmpty {
                    categoryAnalysisCard
                }
                if !monthlyStats.isEmpty {
                    monthlyTrendCard
                }
                if !mealTimeStats.isEmpty {
                    mealAnalysisCard
                }
                if let weekdayWeekend {
                    weekdayWeekendCard(weekdayWeekend)
                }
                if !topMerchants.isEmpty {
                    topMerchantsCard
                }
                insightsCard
            }
        }
    }

    private var categoryAnalysisCard: some View {
        let total = sortedCategorySpending.reduce(0) { $0 + $1.value }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("消费类别", symbol: "chart.pie")
                Spacer()
                Text("总计 \(currency(total))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(sortedCategorySpending.enumerated()), id: \.offset) { index, category in
                let amount = category.value
                let ratio = total > 0 ? amount / total : 0
                let tint = paletteColor(index)

                VStack(spacing: 6) {
                    HStack {
                        Label(category.key, systemImage: categoryIcon(for: category.key))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(currency(amount))
                            .font(.caption.weight(.semibold))
                        Text("\(ratio * 100, specifier: "%.0f")%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { proxy in
                        let width = max(proxy.size.width * ratio, 6)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(tint.opacity(0.16))
                            Capsule()
                                .fill(tint)
                                .frame(width: width)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var monthlyTrendCard: some View {
        let ordered = monthlyStats.sorted { $0.month < $1.month }
        let maxValue = max(ordered.map { max($0.totalSpend, $0.totalIncome) }.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("月度趋势", symbol: "chart.line.uptrend.xyaxis")

            ForEach(ordered) { month in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(month.month.replacingOccurrences(of: "-", with: "年") + "月")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("支出 \(currency(month.totalSpend)) / 收入 \(currency(month.totalIncome))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    trendBar(value: month.totalSpend / maxValue, color: .red, title: "支出")
                    trendBar(value: month.totalIncome / maxValue, color: .green, title: "收入")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func trendBar(value: Double, color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            GeometryReader { proxy in
                let width = max(proxy.size.width * value, 4)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.16))
                    Capsule()
                        .fill(color)
                        .frame(width: width)
                }
            }
            .frame(height: 7)
        }
    }

    private var mealAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("用餐分析", symbol: "fork.knife.circle")

            ForEach(["早餐", "午餐", "晚餐", "夜宵"], id: \.self) { period in
                if let stat = mealTimeStats[period] {
                    HStack {
                        Text(period)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("总额 \(currency(stat.totalAmount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("均值 \(currency(stat.avgAmount))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func weekdayWeekendCard(_ stats: (weekday: DayTypeStats, weekend: DayTypeStats)) -> some View {
        let total = max(stats.weekday.totalAmount + stats.weekend.totalAmount, 1)
        let weekdayRatio = stats.weekday.totalAmount / total
        let weekendRatio = stats.weekend.totalAmount / total

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("工作日 vs 周末", symbol: "calendar.day.timeline.left")

            HStack(spacing: 10) {
                dayTypeBox(stats.weekday, color: .blue)
                dayTypeBox(stats.weekend, color: .purple)
            }

            HStack(spacing: 8) {
                Text("占比")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GeometryReader { proxy in
                    let weekdayWidth = proxy.size.width * weekdayRatio
                    let weekendWidth = proxy.size.width * weekendRatio
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.blue)
                            .frame(width: weekdayWidth)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.purple)
                            .frame(width: weekendWidth)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func dayTypeBox(_ stats: DayTypeStats, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stats.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currency(stats.totalAmount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text("\(stats.count) 笔")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("日均 \(currency(stats.avgPerDay))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var topMerchantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("高频消费商户", symbol: "storefront")

            ForEach(Array(topMerchants.prefix(5).enumerated()), id: \.offset) { _, stat in
                HStack {
                    Text(stat.name.isEmpty ? "未知商户" : stat.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Text("\(stat.count)笔")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currency(stat.totalAmount))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("消费洞察", symbol: "lightbulb")

            ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .padding(.top, 6)
                        .foregroundStyle(.blue)
                    Text(insight)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var timeRangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(CampusCardTimeRange.allCases) { range in
                Button {
                    guard selectedTimeRange != range else { return }
                    selectedTimeRange = range
                    Task { await loadData(range: range) }
                } label: {
                    Text(range.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedTimeRange == range ? Color.blue : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedTimeRange == range ? Color.blue.opacity(0.14) : Color(uiColor: .tertiarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    private func missingDataCard(_ text: String) -> some View {
        HStack {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    @MainActor
    private func loadData(range: CampusCardTimeRange) async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        guard await loginState.ensureLogin(type: .campusCard),
              let login = loginState.campusCardLogin else {
            message = "未登录校园卡系统"
            return
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .month, value: -range.months, to: endDate) ?? endDate

        do {
            let api = CampusCardAPI(login: login)
            async let cardInfoTask = api.getCardInfo()
            async let transactionsTask = api.getAllTransactions(startDate: startDate, endDate: endDate, maxPages: 50)

            let info = try await cardInfoTask
            let fetchedTransactions = try await transactionsTask.sorted { $0.time > $1.time }

            cardInfo = info
            transactions = fetchedTransactions
            monthlyStats = api.calculateMonthlyStats(fetchedTransactions)
            categorySpending = api.categorizeSpending(fetchedTransactions)
            mealTimeStats = api.analyzeMealTimes(fetchedTransactions)
            weekdayWeekend = api.analyzeWeekdayVsWeekend(fetchedTransactions)
            message = fetchedTransactions.isEmpty ? "该时间范围内暂无交易记录" : ""
        } catch {
            message = "加载失败：\(error.localizedDescription)"
        }
    }

    private var currentMonthStats: MonthlyStats? {
        let key = monthKey(from: Date())
        return monthlyStats.first(where: { $0.month == key }) ?? monthlyStats.first
    }

    private var previousMonthStats: MonthlyStats? {
        guard let previousDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else {
            return nil
        }
        let key = monthKey(from: previousDate)
        return monthlyStats.first(where: { $0.month == key })
    }

    private func monthDiff(current: MonthlyStats?, previous: MonthlyStats?) -> Double? {
        guard let current, let previous, previous.totalSpend > 0 else {
            return nil
        }
        return (current.totalSpend - previous.totalSpend) / previous.totalSpend * 100
    }

    private var filteredTransactions: [CardTransaction] {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return transactions
        }
        return transactions.filter {
            $0.merchant.localizedCaseInsensitiveContains(searchQuery)
                || $0.type.localizedCaseInsensitiveContains(searchQuery)
                || $0.description.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var groupedTransactions: [TransactionGroup] {
        let groups = Dictionary(grouping: filteredTransactions) { tx in
            String(tx.time.prefix(10))
        }

        return groups.keys.sorted(by: >).map { key in
            let rows = (groups[key] ?? []).sorted { $0.time > $1.time }
            return TransactionGroup(date: key, items: rows)
        }
    }

    private func daySpend(_ transactions: [CardTransaction]) -> Double {
        transactions.filter { $0.amount < 0 }.reduce(0) { $0 + (-$1.amount) }
    }

    private var filteredTotalSpend: Double {
        filteredTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + (-$1.amount) }
    }

    private var filteredTotalIncome: Double {
        filteredTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var sortedCategorySpending: [(key: String, value: Double)] {
        categorySpending.sorted { $0.value > $1.value }
    }

    private var topMerchants: [MerchantStat] {
        let grouped = Dictionary(grouping: transactions.filter { $0.amount < 0 }) { tx in
            tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return grouped.map { merchant, items in
            MerchantStat(
                name: merchant,
                totalAmount: items.reduce(0) { $0 + (-$1.amount) },
                count: items.count
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }

    private var insights: [String] {
        var result: [String] = []

        if let current = currentMonthStats {
            result.append("本月累计支出 \(currency(current.totalSpend))，收入 \(currency(current.totalIncome))，共 \(current.transactionCount) 笔交易。")
        }

        if let diff = monthDiff(current: currentMonthStats, previous: previousMonthStats) {
            let diffText = String(format: "%.0f", abs(diff))
            if diff >= 0 {
                result.append("与上月相比，消费上升 \(diffText)%，建议关注高频商户支出。")
            } else {
                result.append("与上月相比，消费下降 \(diffText)%，整体支出趋势更稳。")
            }
        }

        if let topCategory = sortedCategorySpending.first {
            let totalSpending = max(sortedCategorySpending.reduce(0) { $0 + $1.value }, 1)
            let ratioText = String(format: "%.0f", topCategory.value / totalSpending * 100)
            result.append("主要开销集中在「\(topCategory.key)」，占比约 \(ratioText)%。")
        }

        if let highestMeal = mealTimeStats.max(by: { $0.value.avgAmount < $1.value.avgAmount }) {
            result.append("\(highestMeal.key)人均消费最高，约 \(currency(highestMeal.value.avgAmount))。")
        }

        if let weekdayWeekend {
            let dominant = weekdayWeekend.weekday.totalAmount >= weekdayWeekend.weekend.totalAmount ? "工作日" : "周末"
            result.append("\(dominant)支出更高，可结合课程安排进一步优化消费节奏。")
        }

        if result.isEmpty {
            result.append("当前时间范围内数据较少，建议切换到 3 个月或半年查看趋势。")
        }

        return result
    }

    private func monthKey(from date: Date) -> String {
        Self.monthFormatter.string(from: date)
    }

    private func shortTime(_ raw: String) -> String {
        let parts = raw.split(separator: " ")
        guard parts.count >= 2 else { return raw }
        let time = String(parts[1])
        if time.count >= 5 {
            return String(time.prefix(5))
        }
        return time
    }

    private func friendlyDate(_ raw: String) -> String {
        guard let date = DateFormatter.ymd.date(from: raw) else { return raw }
        if Calendar.current.isDateInToday(date) {
            return "今天"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        }
        return Self.dayFormatter.string(from: date)
    }

    private func currency(_ value: Double, digits: Int = 2, withSymbol: Bool = true) -> String {
        let text = String(format: "%.\(digits)f", value)
        return withSymbol ? "¥\(text)" : text
    }

    private func mealIcon(for period: String) -> String {
        switch period {
        case "早餐":
            return "sunrise"
        case "午餐":
            return "sun.max"
        case "晚餐":
            return "moon.stars"
        default:
            return "bed.double"
        }
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "餐饮":
            return "fork.knife"
        case "超市":
            return "cart"
        case "洗浴":
            return "drop"
        case "水电":
            return "bolt"
        case "学习":
            return "book"
        case "洗衣":
            return "tshirt"
        case "充值":
            return "plus.circle"
        default:
            return "ellipsis.circle"
        }
    }

    private func transactionIcon(for tx: CardTransaction) -> String {
        let target = "\(tx.merchant)\(tx.type)\(tx.description)"
        if target.contains("餐") || target.contains("饭") || target.contains("奶茶") {
            return "fork.knife"
        }
        if target.contains("超市") || target.contains("商店") || target.contains("便利") {
            return "cart"
        }
        if target.contains("电") || target.contains("水费") || target.contains("能源") {
            return "bolt"
        }
        if target.contains("浴") || target.contains("洗澡") {
            return "drop"
        }
        if target.contains("充值") || target.contains("圈存") || target.contains("转账") {
            return "plus.circle"
        }
        return tx.amount < 0 ? "minus.circle" : "plus.circle"
    }

    private func paletteColor(_ index: Int) -> Color {
        let colors: [Color] = [
            .red, .orange, .green, .teal, .blue, .indigo, .purple, .pink
        ]
        return colors[index % colors.count]
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()
}
