import SwiftUI

struct YwtbScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var userInfo: UserInfo?
    @State private var currentWeek: Int?
    @State private var semesterName = ""
    @State private var semesterID = ""
    @State private var startOfTerm = ""
    @State private var message = ""

    var body: some View {
        List {
            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            Section("个人信息") {
                if let userInfo {
                    row("姓名", userInfo.userName)
                    row("学号", userInfo.userUid)
                    row("身份", userInfo.identityTypeName)
                    row("单位", userInfo.organizationName)
                } else {
                    EmptyPlaceholder(title: "暂无个人信息", subtitle: "下拉刷新")
                }
            }

            Section("学期信息") {
                if semesterID.isEmpty, semesterName.isEmpty, currentWeek == nil {
                    Text("暂无学期数据")
                        .foregroundStyle(.secondary)
                } else {
                    if !semesterID.isEmpty {
                        row("学年", semesterID)
                    }
                    if !semesterName.isEmpty {
                        row("学期", semesterName)
                    }
                    if let currentWeek {
                        row("教学周", "第 \(currentWeek) 周")
                    } else {
                        row("教学周", "假期中")
                    }
                    if !startOfTerm.isEmpty {
                        row("开学日期", startOfTerm)
                    }
                }
            }
        }
        .navigationTitle("一网通办")
        .refreshable { await loadData() }
        .task {
            if userInfo == nil {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard await loginState.ensureLogin(type: .ywtb),
              let login = loginState.ywtbLogin else {
            message = "未登录一网通办"
            return
        }

        do {
            let api = YWTBAPI(login: login)
            let info = try await api.getUserInfo()
            let weekInfo = try await api.getCurrentWeekOfTeaching()

            userInfo = info
            loginState.ywtbUserInfo = info

            if let weekInfo {
                currentWeek = weekInfo.week
                semesterName = weekInfo.semesterName
                semesterID = weekInfo.semesterID
                let termNo = weekInfo.semesterName.contains("二") ? "2" : "1"
                startOfTerm = (try? await api.getStartOfTerm(timestamp: "\(weekInfo.semesterID)-\(termNo)")) ?? ""
            } else {
                currentWeek = nil
                semesterName = ""
                semesterID = ""
                startOfTerm = ""
            }

            message = ""
        } catch {
            message = error.localizedDescription
        }
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
