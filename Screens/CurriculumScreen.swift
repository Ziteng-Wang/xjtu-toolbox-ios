import SwiftUI

struct CurriculumScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var currentTerm = ""
    @State private var completedCredits: Double = 0
    @State private var completedCourses = 0
    @State private var message = ""
    @State private var showBrowser = false
    @State private var browserURL = AppConstants.URLS.curriculumOverviewURL

    var body: some View {
        List {
            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            Section("培养进度概览") {
                row("当前学期", currentTerm.isEmpty ? "未知" : currentTerm)
                row("已通过课程", "\(completedCourses)")
                row("已修学分", String(format: "%.1f", completedCredits))
            }

            Section("培养方案") {
                Button {
                    browserURL = AppConstants.URLS.curriculumOverviewURL
                    showBrowser = true
                } label: {
                    Label("打开培养方案总览", systemImage: "safari")
                }

                Button {
                    browserURL = AppConstants.URLS.curriculumCourseTreeURL
                    showBrowser = true
                } label: {
                    Label("打开课程组树", systemImage: "list.bullet.indent")
                }
            }

            Section("说明") {
                Text("iOS 端已提供与 Android 同步的培养进度入口，依赖教务登录态直接访问培养方案页面。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("培养进度")
        .refreshable { await loadData() }
        .task {
            if currentTerm.isEmpty {
                await loadData()
            }
        }
        .sheet(isPresented: $showBrowser) {
            NavigationStack {
                BrowserScreen(initialURL: browserURL)
            }
        }
    }

    private func loadData() async {
        guard await loginState.ensureLogin(type: .jwxt) else {
            message = "未登录教务系统"
            return
        }

        if await loginState.ensureLogin(type: .jwapp),
           let jwappLogin = loginState.jwappLogin {
            do {
                let api = JWAppAPI(login: jwappLogin)
                let basis = try await api.getTimeTableBasis()
                let termScores = try await api.getGrade()
                let passed = termScores
                    .flatMap(\.scoreList)
                    .filter { score in
                        score.passFlag || (score.scoreValue ?? gradeToNumericScore(score.score) ?? 0) >= 60
                    }
                currentTerm = basis.termCode
                completedCourses = passed.count
                completedCredits = passed.reduce(0) { $0 + $1.coursePoint }
                message = ""
                return
            } catch {
                // Fallback to lightweight mode.
            }
        }

        currentTerm = DateFormatter.ymd.string(from: Date())
        completedCourses = 0
        completedCredits = 0
        message = "暂未获取到课程成绩，仍可打开培养方案页面查看进度"
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
