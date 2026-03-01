import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @Binding var showLoginSheet: Bool
    @Binding var preferredLoginType: LoginType

    private let quickEntries: [AppDestination] = [
        .campusCard, .schedule, .paymentCode, .notification
    ]

    private let commonEntries: [AppDestination] = [
        .score, .curriculum, .attendance, .library, .emptyRoom, .ywtb, .judge, .gmis
    ]

    private let statusServices: [(title: String, type: LoginType)] = [
        ("教务", .jwxt),
        ("移动教务", .jwapp),
        ("一网通办", .ywtb),
        ("考勤", .attendance),
        ("图书馆", .library),
        ("校园卡", .campusCard),
        ("研究生评教", .gste)
    ]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileCard
                    quickEntrySection
                    commonAppsSection
                    statusSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("首页")
            .task(id: loginState.isLoggedIn) {
                guard loginState.isLoggedIn,
                      loginState.nsaProfile == nil else {
                    return
                }
                await loginState.loadNsaProfile()
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Self.dateFormatter.string(from: Date()))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                profileAvatar
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(loginState.isLoggedIn ? "你好，\(displayName)" : "西交校园工具箱")
                        .font(.title3.weight(.semibold))
                    Text(loginState.isLoggedIn ? activeIdentityLine : "登录后可查看个人信息与全部服务状态")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if !loginState.isLoggedIn {
                    Button("登录") {
                        preferredLoginType = .jwxt
                        showLoginSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if loginState.isLoggedIn {
                HStack(spacing: 8) {
                    StatusBadge(text: networkModeText, color: networkModeColor)
                    StatusBadge(text: "已连接 \(connectedCount) 个系统", color: .blue)
                }

                if !profileHighlights.isEmpty {
                    Divider()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(profileHighlights.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.value)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.12),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private var quickEntrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "便捷入口", subtitle: "常用功能直达")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(quickEntries) { destination in
                    NavigationLink {
                        destinationView(for: destination).hideGlobalTabBarOnPush()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: destination.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(destination.tintColor)
                                .frame(width: 40, height: 40)
                                .background(destination.tintColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Text(destination.shortTitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var commonAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "常用应用", subtitle: "按卡片快速进入")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(commonEntries) { destination in
                    NavigationLink {
                        destinationView(for: destination).hideGlobalTabBarOnPush()
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                Image(systemName: destination.symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(destination.tintColor)
                                    .frame(width: 36, height: 36)
                                    .background(destination.tintColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Spacer()
                                if let status = serviceStatus(for: destination) {
                                    StatusBadge(text: status.text, color: status.color)
                                }
                            }

                            Text(destination.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(destination.homeSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "系统状态", subtitle: "点击未登录项可快速登录")
            VStack(spacing: 0) {
                ForEach(Array(statusServices.enumerated()), id: \.element.title) { index, service in
                    let connected = isServiceConnected(service.type)
                    Button {
                        guard !connected else { return }
                        preferredLoginType = service.type
                        showLoginSheet = true
                    } label: {
                        HStack {
                            Image(systemName: connected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(connected ? Color.green : Color.secondary)
                            Text(service.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            StatusBadge(text: connected ? "已连接" : "去登录", color: connected ? .green : .gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)

                    if index < statusServices.count - 1 {
                        Divider()
                            .padding(.leading, 42)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var profileAvatar: some View {
        Group {
            if let data = loginState.nsaPhotoData, let image = UIImage(data: data), loginState.isLoggedIn {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                HStack {
                    Text(String(displayName.prefix(1)))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.opacity(0.16))
            }
        }
        .clipShape(Circle())
    }

    private var displayName: String {
        if let name = loginState.nsaProfile?.name, !name.isEmpty {
            return name
        }
        if let name = loginState.ywtbUserInfo?.userName, !name.isEmpty {
            return name
        }
        if loginState.isLoggedIn {
            return loginState.activeUsername
        }
        return "X"
    }

    private var activeIdentityLine: String {
        if let profile = loginState.nsaProfile {
            let collegeMajor = [profile.college, profile.major]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !collegeMajor.isEmpty {
                return "\(profile.studentId) · \(collegeMajor)"
            }
            return profile.studentId
        }
        if let info = loginState.ywtbUserInfo {
            let tags = [info.userUid, info.identityTypeName, info.organizationName]
                .filter { !$0.isEmpty }
            if !tags.isEmpty {
                return tags.joined(separator: " · ")
            }
        }
        return loginState.activeUsername
    }

    private var profileHighlights: [(label: String, value: String)] {
        if let details = loginState.nsaProfile?.details, !details.isEmpty {
            return Array(details.prefix(4).map { (label: $0.label, value: $0.value) })
        }

        var fallback: [(String, String)] = []
        if let info = loginState.ywtbUserInfo {
            if !info.userUid.isEmpty {
                fallback.append(("学号", info.userUid))
            }
            if !info.identityTypeName.isEmpty {
                fallback.append(("身份", info.identityTypeName))
            }
            if !info.organizationName.isEmpty {
                fallback.append(("单位", info.organizationName))
            }
        }
        return fallback
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
        ]
        .compactMap { $0 }
        .count
    }

    private var networkModeText: String {
        switch loginState.isOnCampus {
        case .some(true):
            return "校园网"
        case .some(false):
            return "WebVPN"
        case .none:
            return "网络未检测"
        }
    }

    private var networkModeColor: Color {
        switch loginState.isOnCampus {
        case .some(true):
            return .green
        case .some(false):
            return .orange
        case .none:
            return .gray
        }
    }

    private func isServiceConnected(_ type: LoginType) -> Bool {
        switch type {
        case .attendance:
            return loginState.attendanceLogin != nil
        case .jwxt:
            return loginState.jwxtLogin != nil
        case .jwapp:
            return loginState.jwappLogin != nil
        case .ywtb:
            return loginState.ywtbLogin != nil
        case .library:
            return loginState.libraryLogin?.seatSystemReady == true
        case .campusCard:
            return loginState.campusCardLogin != nil
        case .gmis:
            return loginState.gmisLogin != nil
        case .gste:
            return loginState.gsteLogin != nil
        }
    }

    private func serviceStatus(for destination: AppDestination) -> (text: String, color: Color)? {
        guard let type = destination.requiredLoginType else {
            return nil
        }
        let connected = isServiceConnected(type)
        return (connected ? "已连接" : "待登录", connected ? .green : .gray)
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .schedule:
            ScheduleScreen()
        case .score:
            ScoreScreen()
        case .curriculum:
            CurriculumScreen()
        case .attendance:
            AttendanceScreen()
        case .emptyRoom:
            EmptyRoomScreen()
        case .notification:
            NotificationScreen()
        case .ywtb:
            YwtbScreen()
        case .library:
            LibraryScreen()
        case .campusCard:
            CampusCardScreen()
        case .paymentCode:
            PaymentCodeScreen()
        case .scoreReport:
            ScoreReportScreen()
        case .judge:
            JudgeScreen()
        case .gsteJudge:
            GsteJudgeScreen()
        case .gmis:
            GmisScreen()
        case .browser:
            BrowserScreen()
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private extension AppDestination {
    var shortTitle: String {
        switch self {
        case .campusCard:
            return "校园卡"
        case .schedule:
            return "课表"
        case .paymentCode:
            return "付款码"
        case .notification:
            return "通知"
        case .score:
            return "成绩查询"
        case .curriculum:
            return "培养进度"
        case .attendance:
            return "考勤"
        case .library:
            return "图书馆"
        case .emptyRoom:
            return "空教室"
        case .ywtb:
            return "一网通办"
        case .judge:
            return "本科评教"
        case .gmis:
            return "GMIS"
        case .scoreReport:
            return "报表成绩"
        case .gsteJudge:
            return "研究生评教"
        case .browser:
            return "浏览器"
        }
    }

    var homeSubtitle: String {
        switch self {
        case .score:
            return "成绩查询 · 学业跟踪"
        case .curriculum:
            return "培养方案与课程进度"
        case .attendance:
            return "进出校园记录查询"
        case .library:
            return "座位查询与预约"
        case .emptyRoom:
            return "按校区与时间筛选"
        case .ywtb:
            return "统一服务门户入口"
        case .judge:
            return "本科教学评价"
        case .gmis:
            return "研究生管理系统"
        case .schedule:
            return "课表 / 考试 / 教材"
        case .notification:
            return "教务与学院公告"
        case .campusCard:
            return "余额与消费账单"
        case .paymentCode:
            return "校园支付码"
        case .scoreReport:
            return "细化成绩与报表"
        case .gsteJudge:
            return "研究生课程评教"
        case .browser:
            return "内置浏览器工具"
        }
    }

    var tintColor: Color {
        switch self {
        case .campusCard, .score, .judge:
            return .blue
        case .schedule, .library, .gmis:
            return .teal
        case .paymentCode, .ywtb:
            return .indigo
        case .notification:
            return .orange
        case .curriculum:
            return .mint
        case .attendance, .scoreReport:
            return .green
        case .emptyRoom, .browser:
            return .cyan
        case .gsteJudge:
            return .purple
        }
    }

    var requiredLoginType: LoginType? {
        switch self {
        case .schedule, .curriculum, .judge, .paymentCode:
            return .jwxt
        case .score, .scoreReport:
            return .jwapp
        case .attendance:
            return .attendance
        case .ywtb:
            return .ywtb
        case .library:
            return .library
        case .campusCard:
            return .campusCard
        case .gsteJudge:
            return .gste
        case .gmis:
            return .gmis
        case .emptyRoom, .notification, .browser:
            return nil
        }
    }
}

struct AcademicView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @Binding var showLoginSheet: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("教学") {
                    NavigationLink {
                        ScheduleScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("课表 / 考试 / 教材", systemImage: "calendar")
                    }

                    NavigationLink {
                        ScoreScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("成绩查询", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    NavigationLink {
                        ScoreReportScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("报表成绩", systemImage: "doc.text")
                    }

                    NavigationLink {
                        CurriculumScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("培养进度", systemImage: "list.bullet.clipboard")
                    }
                }

                Section("评教") {
                    NavigationLink {
                        JudgeScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("本科评教", systemImage: "checkmark.seal")
                    }

                    NavigationLink {
                        GsteJudgeScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("研究生评教", systemImage: "graduationcap.circle")
                    }
                }

                Section("研究生") {
                    NavigationLink {
                        GmisScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("GMIS", systemImage: "graduationcap")
                    }
                }
            }
            .navigationTitle("教务")
            .toolbar {
                if !loginState.isLoggedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("登录") { showLoginSheet = true }
                    }
                }
            }
        }
    }
}

struct ToolsView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @Binding var showLoginSheet: Bool

    @State private var webVPNInput = ""
    @State private var webVPNOutput = ""
    @State private var reverseConvert = false

    var body: some View {
        NavigationStack {
            List {
                Section("常用工具") {
                    NavigationLink {
                        AttendanceScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("考勤查询", systemImage: "person.badge.clock")
                    }

                    NavigationLink {
                        LibraryScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("图书馆座位", systemImage: "chair.lounge")
                    }

                    NavigationLink {
                        CampusCardScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("校园卡", systemImage: "creditcard")
                    }

                    NavigationLink {
                        PaymentCodeScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("付款码", systemImage: "qrcode")
                    }

                    NavigationLink {
                        EmptyRoomScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("空教室", systemImage: "building.2")
                    }

                    NavigationLink {
                        NotificationScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("通知公告", systemImage: "bell")
                    }

                    NavigationLink {
                        YwtbScreen().hideGlobalTabBarOnPush()
                    } label: {
                        Label("一网通办", systemImage: "person.text.rectangle")
                    }

                    NavigationLink {
                        BrowserScreen().hideGlobalTabBarOnPush()
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
                            .foregroundStyle(webVPNOutput.hasPrefix("http") ? Color.primary : Color.red)
                            .textSelection(.enabled)

                        if webVPNOutput.hasPrefix("http") {
                            NavigationLink {
                                BrowserScreen(initialURL: webVPNOutput).hideGlobalTabBarOnPush()
                            } label: {
                                Label("在内置浏览器中打开", systemImage: "arrow.up.right.square")
                            }
                        }
                    }
                }
            }
            .navigationTitle("工具")
            .toolbar {
                if !loginState.isLoggedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("登录") { showLoginSheet = true }
                    }
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
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("信息") {
                    NavigationLink {
                        ProfileAccountInfoView().hideGlobalTabBarOnPush()
                    } label: {
                        Label("账号信息", systemImage: "person.crop.circle")
                    }

                    NavigationLink {
                        ProfileYwtbInfoView().hideGlobalTabBarOnPush()
                    } label: {
                        Label("一网通办信息", systemImage: "person.text.rectangle")
                    }

                    NavigationLink {
                        ProfileNsaInfoView().hideGlobalTabBarOnPush()
                    } label: {
                        Label("NSA 个人信息", systemImage: "person.badge.shield.checkmark")
                    }

                    NavigationLink {
                        ProfileNetworkInfoView().hideGlobalTabBarOnPush()
                    } label: {
                        Label("网络模式", systemImage: "network")
                    }

                    NavigationLink {
                        ProfileAboutView().hideGlobalTabBarOnPush()
                    } label: {
                        Label("关于", systemImage: "info.circle")
                    }
                }

                Section("账号操作") {
                    Button(loginState.isLoggedIn ? "退出登录" : "去登录") {
                        if loginState.isLoggedIn {
                            showLogoutAlert = true
                        } else {
                            showLoginSheet = true
                        }
                    }
                    .foregroundStyle(loginState.isLoggedIn ? .red : .blue)
                    .disabled(isLoggingOut)
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
            .alert("确认退出登录？", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    Task { await performLogout() }
                }
            } message: {
                Text("退出后将清除本地登录态和缓存信息。")
            }
        }
    }

    private func performLogout() async {
        isLoggingOut = true
        await loginState.logout()
        isLoggingOut = false
    }
}

struct ProfileAccountInfoView: View {
    @EnvironmentObject private var loginState: AppLoginState

    var body: some View {
        List {
            Section("账号") {
                if loginState.isLoggedIn {
                    ProfileKeyValueRow(key: "用户名", value: loginState.activeUsername)
                    ProfileKeyValueRow(key: "登录系统数", value: "\(connectedCount)")
                } else {
                    Text("尚未登录")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("账号信息")
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
}

struct ProfileYwtbInfoView: View {
    @EnvironmentObject private var loginState: AppLoginState

    var body: some View {
        List {
            Section("一网通办信息") {
                if let info = loginState.ywtbUserInfo {
                    ProfileKeyValueRow(key: "姓名", value: info.userName)
                    ProfileKeyValueRow(key: "学号", value: info.userUid)
                    ProfileKeyValueRow(key: "身份", value: info.identityTypeName)
                    ProfileKeyValueRow(key: "单位", value: info.organizationName)
                } else {
                    Text("暂无个人信息")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NavigationLink {
                    YwtbScreen().hideGlobalTabBarOnPush()
                } label: {
                    Label("打开一网通办详情", systemImage: "person.text.rectangle")
                }
            }
        }
        .navigationTitle("一网通办")
    }
}

struct ProfileNsaInfoView: View {
    @EnvironmentObject private var loginState: AppLoginState

    var body: some View {
        List {
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
                        ProfileKeyValueRow(key: item.label, value: item.value)
                    }
                } else {
                    Text(loginState.nsaError ?? "暂无 NSA 数据")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("刷新 NSA 信息") {
                    Task { await loginState.loadNsaProfile(force: true) }
                }
            }
        }
        .navigationTitle("NSA 信息")
        .task(id: loginState.isLoggedIn) {
            if loginState.isLoggedIn, loginState.nsaProfile == nil {
                await loginState.loadNsaProfile()
            }
        }
    }
}

struct ProfileNetworkInfoView: View {
    @EnvironmentObject private var loginState: AppLoginState

    var body: some View {
        List {
            Section("网络模式") {
                switch loginState.isOnCampus {
                case .some(true):
                    ProfileKeyValueRow(key: "状态", value: "校园网直连")
                case .some(false):
                    ProfileKeyValueRow(key: "状态", value: "WebVPN 代理")
                case .none:
                    ProfileKeyValueRow(key: "状态", value: "未检测")
                }
            }
        }
        .navigationTitle("网络模式")
    }
}

struct ProfileAboutView: View {
    var body: some View {
        List {
            Section("关于") {
                ProfileKeyValueRow(key: "项目", value: "XJTU Toolbox iOS")
                ProfileKeyValueRow(key: "迁移来源", value: "xjtu-toolbox-android")
                Link(destination: URL(string: "https://www.runqinliu666.cn/")!) {
                    Label("作者主页", systemImage: "link")
                }
            }
        }
        .navigationTitle("关于")
    }
}

private struct ProfileKeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

private extension View {
    func hideGlobalTabBarOnPush() -> some View {
        toolbar(.hidden, for: .tabBar)
    }
}
