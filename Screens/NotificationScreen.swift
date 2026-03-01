import SwiftUI

struct NotificationScreen: View {
    @State private var selectedCategory: SourceCategory?
    @State private var selectedSource: NotificationSource = .jwc
    @State private var mergeMode = false
    @State private var selectedSources: Set<NotificationSource> = [.jwc]

    @State private var notifications: [CampusNotification] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage = ""
    @State private var searchQuery = ""
    @State private var isSearchActive = false
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var cache: [String: [CampusNotification]] = [:]

    private let api = NotificationAPI()

    var body: some View {
        VStack(spacing: 0) {
            categorySelector
            Divider()
                .padding(.horizontal, 16)
            sourceSelector

            if mergeMode {
                mergeHint
            }

            if isLoading && !notifications.isEmpty {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .frame(maxWidth: .infinity)
            }

            contentView
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(isSearchActive ? "" : "通知公告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navigationToolbar }
        .task {
            await reloadForSelectionChange()
        }
        .refreshable {
            currentPage = 1
            await loadNotifications(page: 1, append: false)
        }
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        if isSearchActive {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchActive = false
                        searchQuery = ""
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
            }

            ToolbarItem(placement: .principal) {
                searchBarField
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mergeMode.toggle()
                    }
                    if mergeMode, selectedSources.isEmpty {
                        selectedSources = [selectedSource]
                    }
                    if !mergeMode, let first = selectedSources.first {
                        selectedSource = first
                    }
                    Task { await reloadForSelectionChange() }
                } label: {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(mergeMode ? Color.blue : Color.secondary)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchActive = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }

                Button {
                    Task {
                        currentPage = 1
                        await loadNotifications(page: 1, append: false)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var searchBarField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索通知标题...", text: $searchQuery)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .frame(minWidth: 180, idealWidth: 240, maxWidth: 320)
    }

    private var categorySelector: some View {
        let allCategories: [SourceCategory?] = [nil] + SourceCategory.allCases

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(allCategories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    let label = category?.displayName ?? "全部"

                    Button {
                        selectedCategory = category
                    } label: {
                        VStack(spacing: 4) {
                            Text(label)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                                .lineLimit(1)
                            Capsule()
                                .fill(isSelected ? Color.blue : Color.clear)
                                .frame(width: isSelected ? 20 : 0, height: 3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
    }

    private var sourceSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sourcesInCategory) { source in
                    sourceChip(source)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    private func sourceChip(_ source: NotificationSource) -> some View {
        let isSelected = mergeMode ? selectedSources.contains(source) : (selectedSource == source)

        return Button {
            if mergeMode {
                if isSelected {
                    if selectedSources.count > 1 {
                        selectedSources.remove(source)
                        Task { await reloadForSelectionChange() }
                    }
                } else {
                    selectedSources.insert(source)
                    Task { await reloadForSelectionChange() }
                }
            } else {
                guard selectedSource != source else { return }
                selectedSource = source
                Task { await reloadForSelectionChange() }
            }
        } label: {
            Text(source.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.blue.opacity(0.14) : Color(uiColor: .secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private var mergeHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up")
                .font(.caption)
                .foregroundStyle(.blue)
            Text("已选 \(selectedSources.count) 个来源 · 按时间排列")
                .font(.caption2)
                .foregroundStyle(.blue)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading && notifications.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("正在加载通知...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !errorMessage.isEmpty && notifications.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    Task {
                        currentPage = 1
                        await loadNotifications(page: 1, append: false)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredNotifications.isEmpty {
            EmptyPlaceholder(
                title: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无通知" : "没有匹配的通知",
                subtitle: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "当前暂无新通知" : "请尝试更改搜索关键词"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(filteredNotifications.enumerated()), id: \.element.id) { index, item in
                        notificationCard(item)
                            .onAppear {
                                guard shouldLoadMore(at: index) else { return }
                                Task {
                                    isLoadingMore = true
                                    await loadNotifications(page: currentPage + 1, append: true)
                                }
                            }
                    }

                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 16)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func notificationCard(_ notification: CampusNotification) -> some View {
        NavigationLink {
            BrowserScreen(initialURL: notification.link)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(notification.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        if mergeMode {
                            Text(notification.source.displayName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color.blue.opacity(0.14))
                                )
                        }

                        ForEach(notification.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.8)
                                )
                        }
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        if !mergeMode {
                            Text(notification.source.displayName)
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        Text(relativeDate(notification.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var sourcesInCategory: [NotificationSource] {
        if let selectedCategory {
            return NotificationSource.byCategory(selectedCategory)
        }
        return NotificationSource.allCases
    }

    private var filteredNotifications: [CampusNotification] {
        let keyword = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return notifications }
        return notifications.filter { $0.title.localizedCaseInsensitiveContains(keyword) }
    }

    private var cacheKey: String {
        if mergeMode {
            return selectedSources
                .map(\.rawValue)
                .sorted()
                .joined(separator: ",")
        }
        return selectedSource.rawValue
    }

    private func shouldLoadMore(at index: Int) -> Bool {
        guard hasMorePages, !isLoading, !isLoadingMore else { return false }
        return index >= max(0, filteredNotifications.count - 3)
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        switch day {
        case Int.min..<(-1):
            return "\(-day)天后"
        case -1:
            return "明日"
        case 0:
            return "今日"
        case 1:
            return "昨日"
        case 2...6:
            return "\(day)天前"
        case 7...13:
            return "上周"
        case 14...30:
            return "\(day / 7)周前"
        case 31...365:
            return "\(day / 30)个月前"
        default:
            return DateFormatter.ymd.string(from: date)
        }
    }

    @MainActor
    private func reloadForSelectionChange() async {
        currentPage = 1
        hasMorePages = true
        cache[cacheKey].map { notifications = $0 }
        await loadNotifications(page: 1, append: false)
    }

    @MainActor
    private func loadNotifications(page: Int = 1, append: Bool = false) async {
        if !append && cache[cacheKey] == nil {
            isLoading = true
        }
        errorMessage = ""

        let oldCount = notifications.count
        let result: [CampusNotification]
        if mergeMode {
            result = await api.getMergedNotifications(sources: Array(selectedSources), page: page)
        } else {
            result = await api.getNotifications(source: selectedSource, page: page)
        }

        if append {
            notifications = deduplicated(notifications + result)
            if result.isEmpty || notifications.count == oldCount {
                hasMorePages = false
            }
        } else {
            notifications = result
        }

        cache[cacheKey] = notifications
        currentPage = page
        isLoading = false
        isLoadingMore = false
    }

    private func deduplicated(_ list: [CampusNotification]) -> [CampusNotification] {
        var seen: Set<String> = []
        var result: [CampusNotification] = []

        for item in list {
            let key = "\(item.source.rawValue)|\(item.title)|\(item.link)"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }
        return result.sorted { $0.date > $1.date }
    }
}
