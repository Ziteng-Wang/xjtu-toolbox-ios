import SwiftUI

struct GsteJudgeScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var questionnaires: [GraduateQuestionnaire] = []
    @State private var message = ""
    @State private var submitting = false

    var body: some View {
        List {
            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(message.contains("完成") ? .green : .secondary)
                }
            }

            Section("待评列表") {
                if questionnaires.isEmpty {
                    EmptyPlaceholder(title: "暂无待评问卷", subtitle: "可能已全部完成")
                } else {
                    ForEach(questionnaires) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.KCMC)
                                .font(.headline)
                            Text("教师: \(item.JSXM)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(item.TERMNAME.isEmpty ? item.TERMCODE : item.TERMNAME)
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
        .navigationTitle("研究生评教")
        .refreshable { await loadData() }
        .task {
            if questionnaires.isEmpty {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard await loginState.ensureLogin(type: .gste),
              let login = loginState.gsteLogin else {
            message = "未登录研究生评教系统"
            return
        }

        do {
            let api = GsteJudgeAPI(login: login)
            questionnaires = try await api.getQuestionnaires()
            message = questionnaires.isEmpty ? "暂无待评问卷" : ""
        } catch {
            message = "加载失败: \(error.localizedDescription)"
        }
    }

    private func autoJudgeAll() async {
        guard await loginState.ensureLogin(type: .gste),
              let login = loginState.gsteLogin else {
            message = "未登录研究生评教系统"
            return
        }

        submitting = true
        defer { submitting = false }

        do {
            let api = GsteJudgeAPI(login: login)
            var successCount = 0

            for questionnaire in questionnaires {
                let html = try await api.getQuestionnaireHTML(questionnaire)
                let parsed = api.parseForm(from: html)
                let formData = api.autoFill(
                    questions: parsed.questions,
                    meta: parsed.meta,
                    questionnaire: questionnaire,
                    score: 3
                )
                let ok = try await api.submitQuestionnaire(questionnaire, formData: formData)
                if ok {
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
