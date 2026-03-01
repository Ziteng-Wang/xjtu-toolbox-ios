import SwiftUI
import UIKit

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
                    quickLink(title: "付款码", symbol: "qrcode", destination: PaymentCodeScreen())
                    quickLink(title: "培养进度", symbol: "list.bullet.clipboard", destination: CurriculumScreen())
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
                    statusRow("研究生评教", loginState.gsteLogin != nil)
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

                    NavigationLink {
                        CurriculumScreen()
                    } label: {
                        Label("培养进度", systemImage: "list.bullet.clipboard")
                    }
                }

                Section("评教") {
                    NavigationLink {
                        JudgeScreen()
                    } label: {
                        Label("本科评教", systemImage: "checkmark.seal")
                    }

                    NavigationLink {
                        GsteJudgeScreen()
                    } label: {
                        Label("研究生评教", systemImage: "graduationcap.circle")
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

    @State private var webVPNInput = ""
    @State private var webVPNOutput = ""
    @State private var reverseConvert = false

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
                        PaymentCodeScreen()
                    } label: {
                        Label("付款码", systemImage: "qrcode")
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

                    NavigationLink {
                        YwtbScreen()
                    } label: {
                        Label("一网通办", systemImage: "person.text.rectangle")
                    }

                    NavigationLink {
                        BrowserScreen()
                    } label: {
                        Label("内置浏览器", systemImage: "safari")
                    }
                }

                Section("WebVPN 地址互转") {
                    Picker("方向", selection: $reverseConvert) {
                        Text("原始 -> VPN").tag(false)
                        Text("VPN -> 原始").tag(true)
                    }
                    .pickerStyle(.segmented)

                    TextField(
                        reverseConvert ? "输入 WebVPN 地址" : "输入校内地址",
                        text: $webVPNInput
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Button("转换") {
                        let trimmed = webVPNInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            webVPNOutput = ""
                            return
                        }

                        if reverseConvert {
                            if let vpnURL = URL(string: trimmed),
                               let original = WebVPN.originalURL(from: vpnURL) {
                                webVPNOutput = original.absoluteString
                            } else {
                                webVPNOutput = "无法解析该 WebVPN 地址"
                            }
                        } else {
                            let source = normalizeSourceURL(trimmed)
                            if let sourceURL = URL(string: source) {
                                webVPNOutput = WebVPN.vpnURL(for: sourceURL).absoluteString
                            } else {
                                webVPNOutput = "地址格式错误"
                            }
                        }
                    }

                    if !webVPNOutput.isEmpty {
                        Text(webVPNOutput)
                            .font(.footnote)
                            .foregroundStyle(webVPNOutput.hasPrefix("http") ? .primary : .red)
                            .textSelection(.enabled)

                        if webVPNOutput.hasPrefix("http") {
                            NavigationLink {
                                BrowserScreen(initialURL: webVPNOutput)
                            } label: {
                                Label("在内置浏览器中打开", systemImage: "arrow.up.right.square")
                            }
                        }
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

    private func normalizeSourceURL(_ input: String) -> String {
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            return input
        }
        return "https://\(input)"
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
                        row("学号", info.userUid)
                        row("身份", info.identityTypeName)
                        row("单位", info.organizationName)
                    } else {
                        Text("暂无个人信息")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        YwtbScreen()
                    } label: {
                        Label("打开一网通办详情", systemImage: "person.text.rectangle")
                    }
                }

                Section("NSA 个人信息") {
                    if loginState.nsaLoading {
                        ProgressView("正在加载...")
                    } else if let profile = loginState.nsaProfile {
                        HStack(spacing: 12) {
                            if let data = loginState.nsaPhotoData,
                               let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Text(String(profile.name.prefix(1)))
                                            .font(.headline)
                                    }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profile.studentId)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(profile.college) \(profile.major)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        ForEach(profile.details.prefix(10)) { item in
                            row(item.label, item.value)
                        }
                    } else {
                        Text(loginState.nsaError ?? "暂无 NSA 数据")
                            .foregroundStyle(.secondary)
                    }

                    Button("刷新 NSA 信息") {
                        Task { await loginState.loadNsaProfile(force: true) }
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
            .task(id: loginState.isLoggedIn) {
                if loginState.isLoggedIn,
                   loginState.nsaProfile == nil {
                    await loginState.loadNsaProfile()
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
