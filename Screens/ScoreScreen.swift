import SwiftUI

struct ScoreScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var terms: [TermScore] = []
    @State private var gpaInfo: GPAInfo?
    @State private var errorMessage = ""

    var body: some View {
        List {
            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let gpaInfo {
                Section("总览") {
                    HStack {
                        Label("GPA", systemImage: "chart.bar")
                        Spacer()
                        Text(String(format: "%.3f", gpaInfo.gpa))
                            .font(.headline)
                    }
                    HStack {
                        Text("均分")
                        Spacer()
                        Text(String(format: "%.2f", gpaInfo.averageScore))
                    }
                    HStack {
                        Text("总学分")
                        Spacer()
                        Text(String(format: "%.1f", gpaInfo.totalCredits))
                    }
                    HStack {
                        Text("计入课程")
                        Spacer()
                        Text("\(gpaInfo.courseCount)")
                    }
                }
            }

            ForEach(terms) { term in
                Section(term.termName.isEmpty ? term.termCode : term.termName) {
                    ForEach(term.scoreList) { score in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(score.courseName)
                                    .font(.headline)
                                Text("学分 \(String(format: "%.1f", score.coursePoint))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(score.score)
                                    .font(.headline)
                                Text(score.gpa.map { String(format: "GPA %.1f", $0) } ?? "")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("成绩 / GPA")
        .refreshable { await loadData() }
        .task {
            if terms.isEmpty {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard await loginState.ensureLogin(type: .jwapp),
              let login = loginState.jwappLogin else {
            errorMessage = "未登录移动教务"
            return
        }

        do {
            let api = JWAppAPI(login: login)
            let termScores = try await api.getGrade()
            terms = termScores
            gpaInfo = api.calculateGPA(from: termScores)
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
