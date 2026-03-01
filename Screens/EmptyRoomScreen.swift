import SwiftUI

struct EmptyRoomScreen: View {
    @State private var selectedCampus = campusBuildings.keys.sorted().first ?? ""
    @State private var selectedBuilding = ""
    @State private var selectedDate = DateFormatter.ymd.string(from: Date())

    @State private var rooms: [RoomInfo] = []
    @State private var errorMessage = ""

    private let api = EmptyRoomAPI()

    var body: some View {
        List {
            Section("筛选") {
                Picker("校区", selection: $selectedCampus) {
                    ForEach(campusBuildings.keys.sorted(), id: \.self) { campus in
                        Text(campus).tag(campus)
                    }
                }
                .onChange(of: selectedCampus) { _, newValue in
                    selectedBuilding = campusBuildings[newValue]?.first ?? ""
                }

                Picker("教学楼", selection: $selectedBuilding) {
                    ForEach(campusBuildings[selectedCampus] ?? [], id: \.self) { building in
                        Text(building).tag(building)
                    }
                }

                Picker("日期", selection: $selectedDate) {
                    ForEach(api.getAvailableDates(), id: \.self) { date in
                        Text(date).tag(date)
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("教室") {
                if rooms.isEmpty {
                    EmptyPlaceholder(title: "暂无数据", subtitle: "尝试切换校区、教学楼或日期")
                } else {
                    ForEach(rooms) { room in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(room.name)
                                    .font(.headline)
                                Text("容量 \(room.size)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            let freeCount = room.status.filter { $0 == 0 }.count
                            StatusBadge(text: "空闲 \(freeCount)/11", color: freeCount > 0 ? .green : .gray)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("空教室")
        .refreshable { await loadData() }
        .task {
            if selectedBuilding.isEmpty {
                selectedBuilding = campusBuildings[selectedCampus]?.first ?? ""
            }
            await loadData()
        }
        .onChange(of: selectedBuilding) { _, _ in Task { await loadData() } }
        .onChange(of: selectedDate) { _, _ in Task { await loadData() } }
    }

    private func loadData() async {
        guard !selectedCampus.isEmpty, !selectedBuilding.isEmpty else { return }

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
