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
    case scoreReport
    case judge
    case gsteJudge
    case gmis
    case browser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: return "课表 / 考试"
        case .score: return "成绩 / GPA"
        case .curriculum: return "培养进度"
        case .attendance: return "考勤"
        case .emptyRoom: return "空教室"
        case .notification: return "通知"
        case .ywtb: return "一网通办"
        case .library: return "图书馆"
        case .campusCard: return "校园卡"
        case .paymentCode: return "付款码"
        case .scoreReport: return "报表成绩"
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
        case .scoreReport: return "doc.text"
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

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(showLoginSheet: $showLoginSheet)
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(0)

            AcademicView(showLoginSheet: $showLoginSheet)
                .tabItem {
                    Label("教务", systemImage: "graduationcap")
                }
                .tag(1)

            ToolsView(showLoginSheet: $showLoginSheet)
                .tabItem {
                    Label("工具", systemImage: "wrench.and.screwdriver")
                }
                .tag(2)

            ProfileView(showLoginSheet: $showLoginSheet)
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(3)
        }
        .tint(.blue)
        .sheet(isPresented: $showLoginSheet) {
            LoginSheetView()
                .environmentObject(loginState)
        }
    }
}
