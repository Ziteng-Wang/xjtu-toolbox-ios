import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @Binding var showLoginSheet: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("西安交通大学")
                            .font(.title2.weight(.bold))
                        Text("校园工具箱 iOS")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if loginState.isLoggedIn {
                            HStack {
                                Text("当前账号: \(loginState.activeUsername)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                StatusBadge(
                                    text: loginState.isOnCampus == false ? "WebVPN" : "直连",
                                    color: loginState.isOnCampus == false ? .orange : .green
                                )
                            }
                        } else {
                            Button("立即登录") {
                                showLoginSheet = true
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("快捷入口") {
                    quickLink(title: "课表 / 考试", symbol: "calendar", destination: ScheduleScreen())
                    quickLink(title: "成绩 / GPA", symbol: "chart.bar.doc.horizontal", destination: ScoreScreen())
                    quickLink(title: "空教室", symbol: "building.2", destination: EmptyRoomScreen())
                    quickLink(title: "通知", symbol: "bell", destination: NotificationScreen())
                }

                Section("系统状态") {
                    statusRow("教务", loginState.jwxtLogin != nil)
                    statusRow("移动教务", loginState.jwappLogin != nil)
                    statusRow("一网通办", loginState.ywtbLogin != nil)
                    statusRow("考勤", loginState.attendanceLogin != nil)
                    statusRow("图书馆", loginState.libraryLogin != nil)
                    statusRow("校园卡", loginState.campusCardLogin != nil)
                }
            }
            .navigationTitle("首页")
        }
    }

    @ViewBuilder
    private func quickLink<Destination: View>(title: String, symbol: String, destination: Destination) -> some View {
        NavigationLink {
            destination
        } label: {
            Label(title, systemImage: symbol)
        }
    }

    private func statusRow(_ title: String, _ active: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            StatusBadge(text: active ? "已连接" : "未登录", color: active ? .green : .gray)
        }
    }
}

struct AcademicView: View {
    @Binding var showLoginSheet: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("教学") {
                    NavigationLink {
                        ScheduleScreen()
                    } label: {
                        Label("课表 / 考试 / 教材", systemImage: "calendar")
                    }

                    NavigationLink {
                        ScoreScreen()
                    } label: {
                        Label("成绩 / GPA", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    NavigationLink {
                        ScoreReportScreen()
                    } label: {
                        Label("报表成绩", systemImage: "doc.text")
                    }
                }

                Section("评教") {
                    NavigationLink {
                        JudgeScreen()
                    } label: {
                        Label("本科评教", systemImage: "checkmark.seal")
                    }
                }

                Section("研究生") {
                    NavigationLink {
                        GmisScreen()
                    } label: {
                        Label("GMIS", systemImage: "graduationcap")
                    }
                }
            }
            .navigationTitle("教务")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("登录") { showLoginSheet = true }
                }
            }
        }
    }
}

struct ToolsView: View {
    @Binding var showLoginSheet: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("常用工具") {
                    NavigationLink {
                        AttendanceScreen()
                    } label: {
                        Label("考勤查询", systemImage: "person.badge.clock")
                    }

                    NavigationLink {
                        LibraryScreen()
                    } label: {
                        Label("图书馆座位", systemImage: "chair.lounge")
                    }

                    NavigationLink {
                        CampusCardScreen()
                    } label: {
                        Label("校园卡", systemImage: "creditcard")
                    }

                    NavigationLink {
                        EmptyRoomScreen()
                    } label: {
                        Label("空教室", systemImage: "building.2")
                    }

                    NavigationLink {
                        NotificationScreen()
                    } label: {
                        Label("通知公告", systemImage: "bell")
                    }
                }
            }
            .navigationTitle("工具")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("登录") { showLoginSheet = true }
                }
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @Binding var showLoginSheet: Bool

    @State private var isLoggingOut = false

    var body: some View {
        NavigationStack {
            List {
                Section("账号") {
                    if loginState.isLoggedIn {
                        row("用户名", loginState.activeUsername)
                        row("登录系统数", "\(connectedCount)")
                    } else {
                        Text("尚未登录")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("一网通办") {
                    if let info = loginState.ywtbUserInfo {
                        row("姓名", info.userName)
                        row("身份", info.identityTypeName)
                        row("单位", info.organizationName)
                    } else {
                        Text("暂无个人信息")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("网络模式") {
                    switch loginState.isOnCampus {
                    case .some(true):
                        row("状态", "校园网直连")
                    case .some(false):
                        row("状态", "WebVPN 代理")
                    case .none:
                        row("状态", "未检测")
                    }
                }

                Section {
                    Button(loginState.isLoggedIn ? "退出登录" : "去登录") {
                        if loginState.isLoggedIn {
                            Task {
                                isLoggingOut = true
                                await loginState.logout()
                                isLoggingOut = false
                            }
                        } else {
                            showLoginSheet = true
                        }
                    }
                    .foregroundStyle(loginState.isLoggedIn ? .red : .blue)
                }

                Section("关于") {
                    row("项目", "XJTU Toolbox iOS")
                    row("迁移来源", "xjtu-toolbox-android")
                    Link(destination: URL(string: "https://www.runqinliu666.cn/")!) {
                        Label("作者主页", systemImage: "link")
                    }
                }
            }
            .overlay {
                if isLoggingOut {
                    ProgressView("正在退出...")
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("登录") { showLoginSheet = true }
                }
            }
        }
    }

    private var connectedCount: Int {
        [
            loginState.attendanceLogin,
            loginState.jwxtLogin,
            loginState.jwappLogin,
            loginState.ywtbLogin,
            loginState.libraryLogin,
            loginState.campusCardLogin,
            loginState.gmisLogin,
            loginState.gsteLogin
        ].compactMap { $0 }.count
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
