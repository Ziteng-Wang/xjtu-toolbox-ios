import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var selectedAreaCode = LibraryAPI.areaMap.values.first ?? "north2east"
    @State private var seats: [SeatInfo] = []
    @State private var recommendations: [SeatInfo] = []
    @State private var areaStats: [String: AreaStats] = [:]
    @State private var message = ""

    var body: some View {
        List {
            Section("区域") {
                Picker("区域", selection: $selectedAreaCode) {
                    ForEach(LibraryAPI.areaMap.sorted(by: { $0.key < $1.key }), id: \.value) { pair in
                        Text(pair.key).tag(pair.value)
                    }
                }
            }

            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(message.contains("成功") ? .green : .secondary)
                }
            }

            Section("推荐座位") {
                if recommendations.isEmpty {
                    Text("暂无推荐")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recommendations) { seat in
                        HStack {
                            Text(seat.seatID)
                            Spacer()
                            Button("预约") {
                                Task { await book(seatID: seat.seatID) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("全部座位") {
                if seats.isEmpty {
                    EmptyPlaceholder(title: "暂无座位数据", subtitle: "下拉刷新")
                } else {
                    ForEach(seats) { seat in
                        HStack {
                            Text(seat.seatID)
                            Spacer()
                            StatusBadge(text: seat.available ? "空闲" : "占用", color: seat.available ? .green : .gray)
                        }
                    }
                }
            }
        }
        .navigationTitle("图书馆座位")
        .refreshable { await loadData() }
        .task {
            if seats.isEmpty {
                await loadData()
            }
        }
        .onChange(of: selectedAreaCode) { _, _ in
            Task { await loadData() }
        }
    }

    private func loadData() async {
        guard await loginState.ensureLogin(type: .library),
              let login = loginState.libraryLogin else {
            message = "未登录图书馆系统"
            return
        }

        let api = LibraryAPI(login: login)
        let result = await api.getSeats(areaCode: selectedAreaCode)

        switch result {
        case let .success(list, stats):
            seats = list
            areaStats = stats
            recommendations = api.recommendSeats(list)
            message = ""
        case let .authError(message, _):
            self.message = message
            seats = []
            recommendations = []
        case let .error(message):
            self.message = message
            seats = []
            recommendations = []
        }
    }

    private func book(seatID: String) async {
        guard await loginState.ensureLogin(type: .library),
              let login = loginState.libraryLogin else {
            message = "未登录图书馆系统"
            return
        }

        let api = LibraryAPI(login: login)
        let result = await api.bookSeat(seatID: seatID, areaCode: selectedAreaCode, autoSwap: true)
        message = result.message
        await loadData()
    }
}
