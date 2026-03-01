import SwiftUI

struct ScoreReportScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var grades: [ReportedGrade] = []
    @State private var message = ""

    var body: some View {
        List {
            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            Section("报表成绩") {
                if grades.isEmpty {
                    EmptyPlaceholder(title: "暂无成绩", subtitle: "下拉刷新")
                } else {
                    ForEach(grades) { grade in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(grade.courseName)
                                    .font(.headline)
                                Text("\(grade.term) · 学分 \(String(format: "%.1f", grade.coursePoint))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(grade.score)
                                    .font(.headline)
                                if let gpa = grade.gpa {
                                    Text(String(format: "GPA %.1f", gpa))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("报表成绩")
        .refreshable { await loadData() }
        .task {
            if grades.isEmpty {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard await loginState.ensureLogin(type: .jwxt),
              let login = loginState.jwxtLogin else {
            message = "未登录教务系统"
            return
        }

        do {
            let api = ScoreReportAPI(login: login)
            grades = try await api.getReportedGrade(studentID: loginState.activeUsername)
            message = ""
        } catch {
            message = error.localizedDescription
        }
    }
}
