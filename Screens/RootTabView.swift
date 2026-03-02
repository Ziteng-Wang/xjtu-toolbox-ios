import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    case schedule
    case score
    case curriculum
    case attendance
    case emptyRoom
    case notification
    case ywtb
    case library
    case campusCard
    case paymentCode
    case judge
    case gsteJudge
    case gmis
    case browser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: return "课表 / 考试"
        case .score: return "成绩查询"
        case .curriculum: return "培养进度"
        case .attendance: return "考勤"
        case .emptyRoom: return "空教室"
        case .notification: return "通知"
        case .ywtb: return "一网通办"
        case .library: return "图书馆"
        case .campusCard: return "校园卡"
        case .paymentCode: return "付款码"
        case .judge: return "评教"
        case .gsteJudge: return "研究生评教"
        case .gmis: return "GMIS"
        case .browser: return "浏览器"
        }
    }

    var symbol: String {
        switch self {
        case .schedule: return "calendar"
        case .score: return "chart.bar.doc.horizontal"
        case .curriculum: return "list.bullet.clipboard"
        case .attendance: return "person.badge.clock"
        case .emptyRoom: return "building.2"
        case .notification: return "bell"
        case .ywtb: return "person.text.rectangle"
        case .library: return "book"
        case .campusCard: return "creditcard"
        case .paymentCode: return "qrcode"
        case .judge: return "checkmark.seal"
        case .gsteJudge: return "graduationcap.circle"
        case .gmis: return "graduationcap"
        case .browser: return "safari"
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var selectedTab = 0
    @State private var showLoginSheet = false
    @State private var showTermsConfirm = false

    private var loginRequestBinding: Binding<Bool> {
        Binding(
            get: { false },
            set: { shouldShow in
                guard shouldShow else { return }
                requestLoginFlow()
            }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(showLoginSheet: loginRequestBinding)
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(0)

            AcademicView(showLoginSheet: loginRequestBinding)
                .tabItem {
                    Label("教务", systemImage: "graduationcap")
                }
                .tag(1)

            ToolsView(showLoginSheet: loginRequestBinding)
                .tabItem {
                    Label("工具", systemImage: "wrench.and.screwdriver")
                }
                .tag(2)

            ProfileView(showLoginSheet: loginRequestBinding)
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(3)
        }
        .tint(.blue)
        .alert("使用条款确认", isPresented: $showTermsConfirm) {
            Button("取消", role: .cancel) {}
            Button("同意并继续") {
                Task {
                    await loginState.acceptEula()
                    showLoginSheet = true
                }
            }
        } message: {
            Text("继续登录即表示你已阅读并同意本应用使用条款与免责声明。账号密码仅用于向学校官方系统发起认证。")
        }
        .fullScreenCover(isPresented: $showLoginSheet) {
            LoginSheetView()
                .environmentObject(loginState)
        }
    }

    private func requestLoginFlow() {
        if loginState.eulaAccepted {
            showLoginSheet = true
        } else {
            showTermsConfirm = true
        }
    }
}
