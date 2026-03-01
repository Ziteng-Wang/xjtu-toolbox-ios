import SwiftUI

struct JudgeScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var questionnaires: [Questionnaire] = []
    @State private var message = ""
    @State private var submitting = false

    var body: some View {
        List {
            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(message.contains("成功") ? .green : .secondary)
                }
            }

            Section("待评列表") {
                if questionnaires.isEmpty {
                    EmptyPlaceholder(title: "暂无待评问卷", subtitle: "可能已全部完成")
                } else {
                    ForEach(questionnaires) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.KCM)
                                .font(.headline)
                            Text("教师: \(item.BPJS)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("问卷: \(item.WJMC)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                Button {
                    Task { await autoJudgeAll() }
                } label: {
                    if submitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("一键评教")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(submitting || questionnaires.isEmpty)
            }
        }
        .navigationTitle("本科评教")
        .refreshable { await loadData() }
        .task {
            if questionnaires.isEmpty {
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
            let api = JudgeAPI(login: login)
            questionnaires = try await api.unfinishedQuestionnaires()
            message = questionnaires.isEmpty ? "暂无待评问卷" : ""
        } catch {
            message = error.localizedDescription
        }
    }

    private func autoJudgeAll() async {
        guard await loginState.ensureLogin(type: .jwxt),
              let login = loginState.jwxtLogin else {
            message = "未登录教务系统"
            return
        }

        submitting = true
        defer { submitting = false }

        do {
            let api = JudgeAPI(login: login)
            let username = loginState.activeUsername
            var successCount = 0

            for q in questionnaires {
                let data = try await api.autoFillQuestionnaire(q: q, username: username, score: "1")
                let result = try await api.submitQuestionnaire(q: q, data: data)
                if result.0 {
                    successCount += 1
                }
            }

            message = "提交完成: \(successCount)/\(questionnaires.count)"
            await loadData()
        } catch {
            message = "评教失败: \(error.localizedDescription)"
        }
    }
}
