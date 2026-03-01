import SwiftUI

struct GmisScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var term = ""
    @State private var schedule: [GmisScheduleItem] = []
    @State private var scores: [GmisScoreItem] = []
    @State private var message = ""

    var body: some View {
        List {
            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            if !term.isEmpty {
                Section("当前学期") {
                    Text(term)
                }
            }

            Section("课表") {
                if schedule.isEmpty {
                    Text("暂无课表")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(schedule) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                            Text("\(item.teacher) · 周\(item.dayOfWeek) 第\(item.periodStart)-\(item.periodEnd)节")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("成绩") {
                if scores.isEmpty {
                    Text("暂无成绩")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(scores) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.courseName)
                                    .font(.headline)
                                Text("学分 \(String(format: "%.1f", item.coursePoint))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String(format: "%.1f", item.score))
                                Text(String(format: "GPA %.1f", item.gpa))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("GMIS")
        .refreshable { await loadData() }
        .task {
            if schedule.isEmpty, scores.isEmpty {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard await loginState.ensureLogin(type: .gmis),
              let login = loginState.gmisLogin else {
            message = "未登录 GMIS"
            return
        }

        do {
            let api = GmisAPI(login: login)
            async let currentTerm = api.getCurrentTerm()
            async let scheduleList = api.getSchedule()
            async let scoreList = api.getScore()

            term = try await currentTerm
            schedule = try await scheduleList
            scores = try await scoreList
            message = ""
        } catch {
            message = error.localizedDescription
        }
    }
}
