import SwiftUI
import UIKit

private enum HomeAvatarStyle: String {
    case campusPhoto
    case animeGirl
    case initial
}

struct HomeView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @Binding var showLoginSheet: Bool
    @AppStorage("xjtu.home.avatar.style") private var avatarStyleRaw = HomeAvatarStyle.campusPhoto.rawValue
    @State private var quickLoginType: LoginType?
    @State private var quickLoginError: String?
    @State private var showAvatarStylePicker = false

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
            .onChange(of: loginState.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn {
                    quickLoginError = nil
                }
            }
            .confirmationDialog("选择头像", isPresented: $showAvatarStylePicker, titleVisibility: .visible) {
                if loginState.nsaPhotoData != nil {
                    Button("使用教务照片") {
                        avatarStyleRaw = HomeAvatarStyle.campusPhoto.rawValue
                    }
                }
                Button("使用二次元头像") {
                    avatarStyleRaw = HomeAvatarStyle.animeGirl.rawValue
                }
                Button("使用字母头像") {
                    avatarStyleRaw = HomeAvatarStyle.initial.rawValue
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Self.dateFormatter.string(from: Date()))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                if loginState.isLoggedIn {
                    Button {
                        showAvatarStylePicker = true
                    } label: {
                        profileAvatar
                            .frame(width: 58, height: 58)
                            .overlay(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                                    .overlay {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.blue)
                                    }
                                    .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                            }
                    }
                    .buttonStyle(.plain)
                } else {
                    profileAvatar
                        .frame(width: 58, height: 58)
                }

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
            sectionHeader(title: "系统状态", subtitle: "点击未连接项会自动用当前账号认证")
            VStack(spacing: 0) {
                ForEach(Array(statusServices.enumerated()), id: \.element.title) { index, service in
                    let connected = isServiceConnected(service.type)
                    let isLoading = quickLoginType == service.type
                    Button {
                        guard !connected, !isLoading else { return }
                        quickLogin(service.type)
                    } label: {
                        HStack {
                            Image(systemName: connected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(connected ? Color.green : Color.secondary)
                            Text(service.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            StatusBadge(
                                text: connected ? "已连接" : (isLoading ? "登录中" : "自动登录"),
                                color: connected ? .green : (isLoading ? .blue : .gray)
                            )
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

            if let quickLoginError, !quickLoginError.isEmpty {
                Text(quickLoginError)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var profileAvatar: some View {
        Group {
            switch selectedAvatarStyle {
            case .campusPhoto:
                if let data = loginState.nsaPhotoData, let image = UIImage(data: data), loginState.isLoggedIn {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    initialAvatar
                }
            case .animeGirl:
                animeAvatar
            case .initial:
                initialAvatar
            }
        }
        .clipShape(Circle())
    }

    private var selectedAvatarStyle: HomeAvatarStyle {
        HomeAvatarStyle(rawValue: avatarStyleRaw) ?? .campusPhoto
    }

    private var initialAvatar: some View {
        HStack {
            Text(String(displayName.prefix(1)))
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue.opacity(0.16))
    }

    private var animeAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.44, green: 0.68, blue: 0.96), Color(red: 0.92, green: 0.56, blue: 0.84)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(Color(red: 1.0, green: 0.92, blue: 0.86))
                .frame(width: 38, height: 38)
                .offset(y: 9)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.24, green: 0.28, blue: 0.54))
                .frame(width: 48, height: 22)
                .offset(y: -11)
            Circle()
                .fill(Color(red: 0.24, green: 0.28, blue: 0.54))
                .frame(width: 40, height: 30)
                .offset(y: -18)
            Capsule()
                .fill(Color(red: 0.16, green: 0.2, blue: 0.38))
                .frame(width: 5, height: 8)
                .offset(x: -7, y: 10)
            Capsule()
                .fill(Color(red: 0.16, green: 0.2, blue: 0.38))
                .frame(width: 5, height: 8)
                .offset(x: 7, y: 10)
            Capsule()
                .fill(Color(red: 0.93, green: 0.41, blue: 0.6))
                .frame(width: 8, height: 3)
                .offset(y: 18)
            Circle()
                .fill(Color(red: 0.98, green: 0.68, blue: 0.78).opacity(0.5))
                .frame(width: 6, height: 6)
                .offset(x: -12, y: 15)
            Circle()
                .fill(Color(red: 0.98, green: 0.68, blue: 0.78).opacity(0.5))
                .frame(width: 6, height: 6)
                .offset(x: 12, y: 15)
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .offset(x: 15, y: -17)
        }
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
        return (connected ? "已连接" : "自动登录", connected ? .green : .gray)
    }

    private func quickLogin(_ type: LoginType) {
        if !loginState.hasCredentials {
            quickLoginError = "请先登录一次，保存账号和密码"
            showLoginSheet = true
            return
        }

        quickLoginType = type
        quickLoginError = nil

        Task {
            let success = await loginState.ensureLogin(type: type)
            await MainActor.run {
                quickLoginType = nil
                if success {
                    quickLoginError = nil
                } else {
                    quickLoginError = loginState.lastLoginError ?? "自动登录失败，请稍后重试"
                }
            }
        }
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
        case .attendance:
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
        case .score:
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    academicHeader

                    sectionTitle("教学服务", subtitle: "常用教务能力")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        academicCard(
                            title: "课表 / 考试 / 教材",
                            subtitle: "课程安排与教材",
                            icon: "calendar",
                            color: .teal
                        ) {
                            ScheduleScreen()
                        }

                        academicCard(
                            title: "成绩查询",
                            subtitle: "移动教务成绩",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .blue
                        ) {
                            ScoreScreen()
                        }

                        academicCard(
                            title: "培养进度",
                            subtitle: "培养方案与完成度",
                            icon: "list.bullet.clipboard",
                            color: .mint
                        ) {
                            CurriculumScreen()
                        }
                    }

                    sectionTitle("评教与研究生", subtitle: "更多教学服务")
                    VStack(spacing: 10) {
                        academicRowCard(
                            title: "本科评教",
                            subtitle: "本科课程教学评价",
                            icon: "checkmark.seal",
                            color: .blue
                        ) {
                            JudgeScreen()
                        }

                        academicRowCard(
                            title: "研究生评教",
                            subtitle: "研究生课程评价",
                            icon: "graduationcap.circle",
                            color: .purple
                        ) {
                            GsteJudgeScreen()
                        }

                        academicRowCard(
                            title: "GMIS",
                            subtitle: "研究生课表与成绩",
                            icon: "graduationcap",
                            color: .teal
                        ) {
                            GmisScreen()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
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

    private var academicHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("教务中心")
                        .font(.title2.weight(.bold))
                    Text("课表、成绩、培养进度与评教入口")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.blue)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.14), Color(uiColor: .secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    @ViewBuilder
    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func academicCard<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination().hideGlobalTabBarOnPush()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
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

    @ViewBuilder
    private func academicRowCard<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination().hideGlobalTabBarOnPush()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ToolsView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @Binding var showLoginSheet: Bool

    @State private var webVPNInput = ""
    @State private var webVPNOutput = ""
    @State private var reverseConvert = false

    private enum ToolRoute: String, Identifiable {
        case attendance
        case library
        case campusCard
        case paymentCode
        case emptyRoom
        case notification
        case ywtb
        case browser

        var id: String { rawValue }
    }

    private struct ToolItem: Identifiable {
        let route: ToolRoute
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let tag: String

        var id: ToolRoute { route }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    toolsHeader
                    featuredSection
                    servicesSection

                    sectionTitle("WebVPN 地址互转", subtitle: "校内地址与 VPN 地址一键转换")
                    webVPNConverterCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
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

    private var featuredTools: [ToolItem] {
        [
            ToolItem(route: .campusCard, title: "校园卡", subtitle: "余额、流水与消费分析", icon: "creditcard", color: .blue, tag: "生活高频"),
            ToolItem(route: .paymentCode, title: "付款码", subtitle: "校园支付快捷码", icon: "qrcode", color: .indigo, tag: "移动支付"),
            ToolItem(route: .library, title: "图书馆座位", subtitle: "查空位与预约", icon: "chair.lounge", color: .teal, tag: "自习必备"),
            ToolItem(route: .attendance, title: "考勤查询", subtitle: "进出校记录追踪", icon: "person.badge.clock", color: .green, tag: "进出记录")
        ]
    }

    private var serviceTools: [ToolItem] {
        [
            ToolItem(route: .emptyRoom, title: "空教室", subtitle: "按教学楼与时段筛选", icon: "building.2", color: .cyan, tag: "教室检索"),
            ToolItem(route: .notification, title: "通知公告", subtitle: "教务信息集中查看", icon: "bell", color: .orange, tag: "消息聚合"),
            ToolItem(route: .ywtb, title: "一网通办", subtitle: "统一服务入口", icon: "person.text.rectangle", color: .indigo, tag: "统一认证"),
            ToolItem(route: .browser, title: "内置浏览器", subtitle: "校园站点快速访问", icon: "safari", color: .cyan, tag: "网页工具")
        ]
    }

    private var toolsHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("工具箱")
                        .font(.title2.weight(.bold))
                    Text("生活缴费、学习查询与校园服务一屏直达")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.indigo)
            }

            HStack(spacing: 8) {
                StatusBadge(text: networkModeText, color: networkModeColor)
                StatusBadge(text: "已连接 \(connectedServiceCount) 项服务", color: .blue)
            }
        }
        .padding(16)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color.indigo.opacity(0.16), Color.cyan.opacity(0.12), Color(uiColor: .secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 140, height: 140)
                    .offset(x: 120, y: -70)
                Circle()
                    .fill(Color.indigo.opacity(0.16))
                    .frame(width: 100, height: 100)
                    .offset(x: -120, y: 55)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("高频入口", subtitle: "常用工具优先展示")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(featuredTools) { item in
                    featuredToolCard(item)
                }
            }
        }
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("服务入口", subtitle: "全部工具与辅助能力")

            VStack(spacing: 10) {
                ForEach(serviceTools) { item in
                    serviceRowCard(item)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func featuredToolCard(_ item: ToolItem) -> some View {
        NavigationLink {
            destinationView(for: item.route).hideGlobalTabBarOnPush()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(item.color)
                        .frame(width: 34, height: 34)
                        .background(item.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Spacer()

                    Text(item.tag)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let status = serviceStatus(for: item.route) {
                    StatusBadge(text: status.text, color: status.color)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [item.color.opacity(0.16), Color(uiColor: .secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(item.color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func serviceRowCard(_ item: ToolItem) -> some View {
        NavigationLink {
            destinationView(for: item.route).hideGlobalTabBarOnPush()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.color)
                    .frame(width: 36, height: 36)
                    .background(item.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(item.tag)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destinationView(for route: ToolRoute) -> some View {
        switch route {
        case .attendance:
            AttendanceScreen()
        case .library:
            LibraryScreen()
        case .campusCard:
            CampusCardScreen()
        case .paymentCode:
            PaymentCodeScreen()
        case .emptyRoom:
            EmptyRoomScreen()
        case .notification:
            NotificationScreen()
        case .ywtb:
            YwtbScreen()
        case .browser:
            BrowserScreen()
        }
    }

    private var webVPNConverterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                convertWebVPNAddress()
            } label: {
                Label("生成地址", systemImage: "arrow.left.arrow.right.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

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
                            .font(.footnote.weight(.semibold))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func convertWebVPNAddress() {
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

    private func serviceStatus(for route: ToolRoute) -> (text: String, color: Color)? {
        switch route {
        case .attendance:
            return loginState.attendanceLogin == nil ? ("自动登录", .gray) : ("已连接", .green)
        case .library:
            return loginState.libraryLogin?.seatSystemReady == true ? ("已连接", .green) : ("自动登录", .gray)
        case .campusCard:
            return loginState.campusCardLogin == nil ? ("自动登录", .gray) : ("已连接", .green)
        case .paymentCode:
            return loginState.jwxtLogin == nil ? ("自动登录", .gray) : ("已连接", .green)
        case .ywtb:
            return loginState.ywtbLogin == nil ? ("自动登录", .gray) : ("已连接", .green)
        case .emptyRoom, .notification, .browser:
            return nil
        }
    }

    private var connectedServiceCount: Int {
        var count = 0
        if loginState.attendanceLogin != nil {
            count += 1
        }
        if loginState.libraryLogin?.seatSystemReady == true {
            count += 1
        }
        if loginState.campusCardLogin != nil {
            count += 1
        }
        if loginState.jwxtLogin != nil {
            count += 1
        }
        if loginState.ywtbLogin != nil {
            count += 1
        }
        return count
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    profileHeader

                    sectionTitle("个人信息", subtitle: "查看与同步个人资料")
                    VStack(spacing: 10) {
                        profileLinkCard(
                            title: "账号信息",
                            subtitle: "登录账号与系统状态",
                            icon: "person.crop.circle",
                            color: .blue
                        ) {
                            ProfileAccountInfoView()
                        }

                        profileLinkCard(
                            title: "一网通办信息",
                            subtitle: "身份与组织信息",
                            icon: "person.text.rectangle",
                            color: .indigo
                        ) {
                            ProfileYwtbInfoView()
                        }

                        profileLinkCard(
                            title: "NSA 个人信息",
                            subtitle: "学工系统资料",
                            icon: "person.badge.shield.checkmark",
                            color: .teal
                        ) {
                            ProfileNsaInfoView()
                        }
                    }

                    sectionTitle("其他", subtitle: "网络与应用信息")
                    VStack(spacing: 10) {
                        profileLinkCard(
                            title: "网络模式",
                            subtitle: "校园网 / WebVPN",
                            icon: "network",
                            color: .orange
                        ) {
                            ProfileNetworkInfoView()
                        }

                        profileLinkCard(
                            title: "关于",
                            subtitle: "版本与项目信息",
                            icon: "info.circle",
                            color: .gray
                        ) {
                            ProfileAboutView()
                        }
                    }

                    actionCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
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

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                avatarView
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.title3.weight(.bold))
                    Text(loginState.activeUsername)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: "\(connectedCount) 个系统", color: .blue)
            }

            HStack(spacing: 8) {
                StatusBadge(text: networkModeText, color: networkModeColor)
                if let identity = loginState.ywtbUserInfo?.identityTypeName, !identity.isEmpty {
                    StatusBadge(text: identity, color: .indigo)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.14), Color(uiColor: .secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var avatarView: some View {
        Group {
            if let data = loginState.nsaPhotoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.16))
                    Text(String(displayName.prefix(1)))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.blue)
                }
            }
        }
        .clipShape(Circle())
    }

    @ViewBuilder
    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func profileLinkCard<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination().hideGlobalTabBarOnPush()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("账号操作")
                .font(.headline)
            Button(loginState.isLoggedIn ? "退出登录" : "去登录") {
                if loginState.isLoggedIn {
                    showLogoutAlert = true
                } else {
                    showLoginSheet = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(loginState.isLoggedIn ? .red : .blue)
            .disabled(isLoggingOut)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var displayName: String {
        if let name = loginState.nsaProfile?.name, !name.isEmpty {
            return name
        }
        if let name = loginState.ywtbUserInfo?.userName, !name.isEmpty {
            return name
        }
        return loginState.activeUsername
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
