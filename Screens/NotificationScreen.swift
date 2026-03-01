import SwiftUI

struct NotificationScreen: View {
    @State private var selectedSource: NotificationSource = .jwc
    @State private var notifications: [CampusNotification] = []
    @State private var errorMessage = ""
    @State private var isLoading = false

    private let api = NotificationAPI()

    var body: some View {
        List {
            Section("来源") {
                Picker("来源", selection: $selectedSource) {
                    ForEach(NotificationSource.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("通知列表") {
                if notifications.isEmpty {
                    EmptyPlaceholder(title: isLoading ? "加载中" : "暂无通知", subtitle: "下拉刷新或更换来源")
                } else {
                    ForEach(notifications) { item in
                        NavigationLink {
                            BrowserScreen(initialURL: item.link)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                HStack {
                                    Text(item.source.displayName)
                                    Text(DateFormatter.ymd.string(from: item.date))
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("通知")
        .refreshable { await loadData() }
        .task {
            if notifications.isEmpty {
                await loadData()
            }
        }
        .onChange(of: selectedSource) { _, _ in
            Task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let items = await api.getNotifications(source: selectedSource, page: 1)
        notifications = items
        errorMessage = items.isEmpty ? "该来源暂时无数据或站点不可达" : ""
    }
}
