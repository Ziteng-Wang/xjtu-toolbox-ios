import SwiftUI

private struct LibraryAreaOption: Identifiable {
    let name: String
    let code: String

    var id: String { code }
}

struct LibraryScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    private static let defaultAreaCode = LibraryAPI.areaMap
        .sorted(by: { $0.key < $1.key })
        .first?.value ?? "north2east"

    @State private var selectedAreaCode = defaultAreaCode
    @State private var seats: [SeatInfo] = []
    @State private var recommendations: [SeatInfo] = []
    @State private var areaStats: [String: AreaStats] = [:]
    @State private var message = ""
    @State private var searchQuery = ""
    @State private var showAvailableOnly = false
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var myBooking: MyBookingInfo?
    @State private var pendingOperationText: String?
    @State private var isRefreshingMyBooking = false

    private var areaOptions: [LibraryAreaOption] {
        LibraryAPI.areaMap
            .map { LibraryAreaOption(name: $0.key, code: $0.value) }
            .sorted(by: { $0.name < $1.name })
    }

    var body: some View {
        Group {
            if isLoading && !hasLoaded {
                loadingView
            } else {
                contentView
            }
        }
        .navigationTitle("图书馆座位")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadData() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .refreshable { await loadData() }
        .task {
            if !hasLoaded {
                await loadData()
            }
        }
        .onChange(of: selectedAreaCode) { _, _ in
            Task { await loadData() }
        }
        .overlay {
            if let pendingOperationText {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.thinMaterial)
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(pendingOperationText)
                            .font(.footnote)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(width: 160, height: 48)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("正在加载座位数据...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                summaryCard
                myBookingCard
                areaSelectorCard
                filterCard

                if !message.isEmpty {
                    messageCard
                }

                recommendationSection
                seatSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollIndicators(.hidden)
    }

    private var summaryCard: some View {
        let stats = areaStats[selectedAreaCode]
        let available = stats?.available ?? seats.filter(\.available).count
        let total = stats?.total ?? seats.count
        let occupancy = total > 0 ? Double(available) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedAreaName)
                        .font(.headline)
                    Text("当前区域空闲情况")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: "\(available)/\(total)", color: available > 0 ? .green : .gray)
            }

            ProgressView(value: occupancy)
                .tint(available > 0 ? .green : .gray)

            HStack(spacing: 10) {
                summaryItem(title: "空闲", value: "\(available)", tint: .green)
                summaryItem(title: "占用", value: "\(max(total - available, 0))", tint: .orange)
                summaryItem(title: "推荐", value: "\(recommendations.count)", tint: .blue)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func summaryItem(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var areaSelectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("区域切换")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(areaOptions) { area in
                        areaChip(area)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var myBookingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("我的预约")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await refreshMyBooking() }
                } label: {
                    if isRefreshingMyBooking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRefreshingMyBooking || pendingOperationText != nil)
            }

            if let myBooking {
                VStack(alignment: .leading, spacing: 6) {
                    Text(myBooking.seatID ?? "未知座位")
                        .font(.title3.weight(.bold))

                    let details = [myBooking.area, myBooking.statusText]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                let actions = bookingActions(myBooking)
                if !actions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(actions, id: \.label) { action in
                                if action.label.contains("取消") {
                                    Button(action.label) {
                                        Task { await executeBookingAction(label: action.label, url: action.url) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .controlSize(.small)
                                    .disabled(pendingOperationText != nil)
                                } else {
                                    Button(action.label) {
                                        Task { await executeBookingAction(label: action.label, url: action.url) }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    .controlSize(.small)
                                    .disabled(pendingOperationText != nil)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("暂无预约")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func areaChip(_ area: LibraryAreaOption) -> some View {
        let selected = selectedAreaCode == area.code

        return Button {
            selectedAreaCode = area.code
        } label: {
            Text(area.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? Color.blue : Color.secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? Color.blue.opacity(0.14) : Color(uiColor: .tertiarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private var filterCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索座位号", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle(isOn: $showAvailableOnly) {
                Text("仅显示空闲座位")
                    .font(.footnote)
            }
            .tint(.green)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var messageCard: some View {
        let success = message.contains("成功")
        let failed = message.contains("失败") || message.contains("未登录")
        let color: Color = success ? .green : (failed ? .red : .secondary)

        return HStack(spacing: 8) {
            Image(systemName: success ? "checkmark.circle.fill" : (failed ? "exclamationmark.triangle.fill" : "info.circle"))
                .foregroundStyle(color)
            Text(message)
                .font(.footnote)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("推荐座位")
                    .font(.headline)
                Spacer()
                Text("\(recommendations.count) 个")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if recommendations.isEmpty {
                emptyInlineCard("暂无推荐座位")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recommendations) { seat in
                            recommendationSeatCard(seat)
                        }
                    }
                }
            }
        }
    }

    private func recommendationSeatCard(_ seat: SeatInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(seat.seatID)
                .font(.title3.weight(.bold))
            StatusBadge(text: seat.available ? "空闲" : "占用", color: seat.available ? .green : .gray)

            Button("预约") {
                Task { await book(seatID: seat.seatID) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!seat.available || pendingOperationText != nil)
        }
        .frame(width: 130, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var seatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("全部座位")
                    .font(.headline)
                Spacer()
                Text("\(filteredSeats.count) 个")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if filteredSeats.isEmpty {
                emptyInlineCard("暂无符合条件的座位")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(filteredSeats) { seat in
                        seatCard(seat)
                    }
                }
            }
        }
    }

    private func seatCard(_ seat: SeatInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(seat.seatID)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(seat.available ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }

            Text(seat.available ? "空闲可预约" : "当前占用")
                .font(.caption)
                .foregroundStyle(.secondary)

            if seat.available {
                Button("预约") {
                    Task { await book(seatID: seat.seatID) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(pendingOperationText != nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func emptyInlineCard(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
            Text(title)
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

    private var selectedAreaName: String {
        areaOptions.first(where: { $0.code == selectedAreaCode })?.name ?? "未知区域"
    }

    private var filteredSeats: [SeatInfo] {
        var list = seats

        if showAvailableOnly {
            list = list.filter(\.available)
        }

        let keyword = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            list = list.filter { $0.seatID.localizedCaseInsensitiveContains(keyword) }
        }

        return list
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        guard await loginState.ensureLogin(type: .library),
              let login = loginState.libraryLogin else {
            let diagnostic = loginState.libraryLogin?.diagnosticInfo ?? ""
            message = diagnostic.isEmpty ? "未登录图书馆系统" : diagnostic
            seats = []
            recommendations = []
            return
        }

        let api = LibraryAPI(login: login)
        async let seatResult = api.getSeats(areaCode: selectedAreaCode)
        async let bookingResult = api.getMyBooking()
        let result = await seatResult
        let currentBooking = await bookingResult

        switch result {
        case let .success(list, stats):
            seats = list
            areaStats = stats
            recommendations = api.recommendSeats(list)
            myBooking = currentBooking
            message = ""
        case let .authError(msg, _):
            message = msg
            seats = []
            recommendations = []
            myBooking = nil
        case let .error(msg):
            message = msg
            seats = []
            recommendations = []
            myBooking = nil
        }
    }

    @MainActor
    private func book(seatID: String) async {
        guard pendingOperationText == nil else { return }

        guard await loginState.ensureLogin(type: .library),
              let login = loginState.libraryLogin else {
            let diagnostic = loginState.libraryLogin?.diagnosticInfo ?? ""
            message = diagnostic.isEmpty ? "未登录图书馆系统" : diagnostic
            return
        }

        pendingOperationText = "正在预约座位..."
        defer { pendingOperationText = nil }

        let api = LibraryAPI(login: login)
        let result = await api.bookSeat(seatID: seatID, areaCode: selectedAreaCode, autoSwap: true)
        message = result.message
        await loadData()
    }

    @MainActor
    private func refreshMyBooking() async {
        guard pendingOperationText == nil else { return }
        guard await loginState.ensureLogin(type: .library),
              let login = loginState.libraryLogin else {
            let diagnostic = loginState.libraryLogin?.diagnosticInfo ?? ""
            message = diagnostic.isEmpty ? "未登录图书馆系统" : diagnostic
            myBooking = nil
            return
        }

        isRefreshingMyBooking = true
        defer { isRefreshingMyBooking = false }

        let api = LibraryAPI(login: login)
        myBooking = await api.getMyBooking()
        if myBooking == nil {
            message = "当前暂无预约"
        } else if message == "当前暂无预约" {
            message = ""
        }
    }

    @MainActor
    private func executeBookingAction(label: String, url: String) async {
        guard pendingOperationText == nil else { return }
        guard await loginState.ensureLogin(type: .library),
              let login = loginState.libraryLogin else {
            let diagnostic = loginState.libraryLogin?.diagnosticInfo ?? ""
            message = diagnostic.isEmpty ? "未登录图书馆系统" : diagnostic
            return
        }

        pendingOperationText = "正在\(label)..."
        defer { pendingOperationText = nil }

        let api = LibraryAPI(login: login)
        let result = await api.executeAction(url)
        message = "\(label)：\(result.message)"
        await loadData()
    }

    private func bookingActions(_ booking: MyBookingInfo) -> [(label: String, url: String)] {
        let actionOrder = ["取消预约": 0, "签到": 1, "临时离馆": 2, "回馆签到": 3]
        return booking.actionURLs
            .map { (label: $0.key, url: $0.value) }
            .sorted { lhs, rhs in
                let left = actionOrder[lhs.label] ?? 100
                let right = actionOrder[rhs.label] ?? 100
                if left != right {
                    return left < right
                }
                return lhs.label < rhs.label
            }
    }
}
