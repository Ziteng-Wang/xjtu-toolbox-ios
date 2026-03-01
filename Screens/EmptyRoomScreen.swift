import SwiftUI

private enum RoomTimeFilter: String, CaseIterable, Identifiable {
    case all
    case current
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部时段"
        case .current:
            return "当前节"
        case .morning:
            return "上午"
        case .afternoon:
            return "下午"
        case .evening:
            return "晚上"
        }
    }
}

struct EmptyRoomScreen: View {
    @State private var selectedCampus = campusBuildings.keys.sorted().first ?? ""
    @State private var selectedBuilding = ""
    @State private var selectedDate = DateFormatter.ymd.string(from: Date())
    @State private var selectedTimeFilter: RoomTimeFilter = .all
    @State private var searchQuery = ""

    @State private var rooms: [RoomInfo] = []
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var hasLoaded = false

    private let api = EmptyRoomAPI()

    private let periodTimes: [(start: Int, end: Int)] = [
        (8 * 60, 8 * 60 + 50),
        (9 * 60, 9 * 60 + 50),
        (10 * 60 + 10, 11 * 60),
        (11 * 60 + 10, 12 * 60),
        (14 * 60, 14 * 60 + 50),
        (15 * 60, 15 * 60 + 50),
        (16 * 60 + 10, 17 * 60),
        (17 * 60 + 10, 18 * 60),
        (19 * 60, 19 * 60 + 50),
        (20 * 60, 20 * 60 + 50),
        (21 * 60, 21 * 60 + 50)
    ]

    var body: some View {
        Group {
            if isLoading && !hasLoaded {
                loadingView
            } else {
                contentView
            }
        }
        .navigationTitle("空教室")
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
            if selectedBuilding.isEmpty {
                selectedBuilding = campusBuildings[selectedCampus]?.first ?? ""
            }
            if !hasLoaded {
                await loadData()
            }
        }
        .onChange(of: selectedCampus) { _, newValue in
            selectedBuilding = campusBuildings[newValue]?.first ?? ""
            selectedTimeFilter = .all
        }
        .onChange(of: selectedBuilding) { _, _ in
            Task { await loadData() }
        }
        .onChange(of: selectedDate) { _, _ in
            selectedTimeFilter = .all
            Task { await loadData() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("正在查询空教室...")
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
                selectorCard
                timeFilterCard
                roomListCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollIndicators(.hidden)
    }

    private var summaryCard: some View {
        let total = rooms.count
        let freeNow = currentPeriod.map { period in
            rooms.filter { room in
                period < room.status.count && room.status[period] == 0
            }.count
        } ?? 0
        let freeAny = rooms.filter { $0.status.contains(0) }.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedBuilding.isEmpty ? "选择教学楼" : "\(selectedCampus) · \(selectedBuilding)")
                        .font(.headline)
                    Text(selectedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: "\(total) 间教室", color: .blue)
            }

            HStack(spacing: 10) {
                summaryStat(title: "当前节空闲", value: "\(freeNow)", tint: .green)
                summaryStat(title: "全天有空", value: "\(freeAny)", tint: .teal)
                summaryStat(title: "筛选后", value: "\(displayedRooms.count)", tint: .indigo)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func summaryStat(title: String, value: String, tint: Color) -> some View {
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
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var selectorCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                selectorMenu(
                    title: "校区",
                    value: selectedCampus,
                    options: campusBuildings.keys.sorted()
                ) { selectedCampus = $0 }

                selectorMenu(
                    title: "教学楼",
                    value: selectedBuilding,
                    options: campusBuildings[selectedCampus] ?? []
                ) { selectedBuilding = $0 }
            }

            HStack(spacing: 8) {
                selectorMenu(
                    title: "日期",
                    value: selectedDate,
                    options: api.getAvailableDates()
                ) { selectedDate = $0 }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索教室", text: $searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemBackground))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func selectorMenu(
        title: String,
        value: String,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { onSelect(option) }
            }
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(value.isEmpty ? "未选择" : value)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeFilterCard: some View {
        let filters: [RoomTimeFilter] = {
            var base: [RoomTimeFilter] = [.all]
            if currentPeriod != nil { base.append(.current) }
            base.append(contentsOf: [.morning, .afternoon, .evening])
            return base
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Text("时段筛选")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters) { filter in
                        timeFilterChip(filter)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                periodLegend("空闲", .green.opacity(0.65))
                periodLegend("占用", .secondary.opacity(0.3))
                if currentPeriod != nil {
                    periodLegend("当前节", .red.opacity(0.7))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func timeFilterChip(_ filter: RoomTimeFilter) -> some View {
        let selected = selectedTimeFilter == filter

        return Button {
            selectedTimeFilter = filter
        } label: {
            Text(filter.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? Color.indigo : Color.secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? Color.indigo.opacity(0.14) : Color(uiColor: .tertiarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private func periodLegend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var roomListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("教室列表")
                    .font(.headline)
                Spacer()
                Text("\(displayedRooms.count) 间")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !errorMessage.isEmpty {
                errorBanner(errorMessage)
            } else if displayedRooms.isEmpty {
                EmptyPlaceholder(title: "暂无符合条件的教室", subtitle: "可尝试切换筛选条件")
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
            } else {
                ForEach(displayedRooms) { room in
                    roomCard(room)
                }
            }
        }
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.1))
        )
    }

    private func roomCard(_ room: RoomInfo) -> some View {
        let freeCount = room.status.filter { $0 == 0 }.count
        let current = currentPeriod
        let consecutive = current.map { consecutiveFree(status: room.status, from: $0) } ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(.headline)
                    Text("容量 \(room.size)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(
                    text: "空闲 \(freeCount)/\(room.status.count)",
                    color: freeCount > 0 ? .green : .gray
                )
            }

            HStack(spacing: 4) {
                ForEach(Array(room.status.enumerated()), id: \.offset) { index, status in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(periodColor(status: status, index: index, current: current))
                        .frame(maxWidth: .infinity, minHeight: 6, maxHeight: 6)
                }
            }

            if let current, current < room.status.count {
                Text(room.status[current] == 0 ? "当前连续空闲 \(consecutive) 节" : "当前节已占用")
                    .font(.caption2)
                    .foregroundStyle(room.status[current] == 0 ? Color.green : Color.orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var currentPeriod: Int? {
        guard selectedDate == DateFormatter.ymd.string(from: Date()) else { return nil }

        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)

        for (index, period) in periodTimes.enumerated() {
            if minutes >= period.start && minutes <= period.end {
                return index
            }

            if index < periodTimes.count - 1 {
                let nextStart = periodTimes[index + 1].start
                if minutes > period.end && minutes < nextStart {
                    return index + 1
                }
            }
        }

        if let firstStart = periodTimes.first?.start, minutes < firstStart {
            return 0
        }
        return nil
    }

    private var displayedRooms: [RoomInfo] {
        var filtered = rooms

        let keyword = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
        }

        filtered = filtered.filter { matchesTimeFilter(room: $0) }

        return filtered.sorted { lhs, rhs in
            let lFree = lhs.status.filter { $0 == 0 }.count
            let rFree = rhs.status.filter { $0 == 0 }.count
            if lFree == rFree {
                return lhs.name < rhs.name
            }
            return lFree > rFree
        }
    }

    private func matchesTimeFilter(room: RoomInfo) -> Bool {
        switch selectedTimeFilter {
        case .all:
            return true
        case .current:
            guard let current = currentPeriod, current < room.status.count else { return true }
            return room.status[current] == 0
        case .morning:
            return hasFreePeriod(room.status, from: 0, to: 3)
        case .afternoon:
            return hasFreePeriod(room.status, from: 4, to: 7)
        case .evening:
            return hasFreePeriod(room.status, from: 8, to: 10)
        }
    }

    private func hasFreePeriod(_ status: [Int], from start: Int, to end: Int) -> Bool {
        guard !status.isEmpty else { return false }
        let lower = max(start, 0)
        let upper = min(end, status.count - 1)
        guard lower <= upper else { return false }
        return status[lower...upper].contains(0)
    }

    private func consecutiveFree(status: [Int], from period: Int) -> Int {
        guard period >= 0, period < status.count else { return 0 }
        var count = 0
        for index in period..<status.count {
            if status[index] == 0 {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private func periodColor(status: Int, index: Int, current: Int?) -> Color {
        let isCurrent = current == index

        if status == 0 {
            return isCurrent ? Color.green : Color.green.opacity(0.6)
        }
        return isCurrent ? Color.red.opacity(0.7) : Color.secondary.opacity(0.28)
    }

    @MainActor
    private func loadData() async {
        guard !selectedCampus.isEmpty, !selectedBuilding.isEmpty else { return }

        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            rooms = try await api.getEmptyRooms(
                campusName: selectedCampus,
                buildingName: selectedBuilding,
                date: selectedDate
            )
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
            rooms = []
        }
    }
}
