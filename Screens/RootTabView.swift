import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    case schedule
    case score
    case attendance
    case emptyRoom
    case notification
    case library
    case campusCard
    case scoreReport
    case judge
    case gmis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: return "课表 / 考试"
        case .score: return "成绩 / GPA"
        case .attendance: return "考勤"
        case .emptyRoom: return "空教室"
        case .notification: return "通知"
        case .library: return "图书馆"
        case .campusCard: return "校园卡"
        case .scoreReport: return "报表成绩"
        case .judge: return "评教"
        case .gmis: return "GMIS"
        }
    }

    var symbol: String {
        switch self {
        case .schedule: return "calendar"
        case .score: return "chart.bar.doc.horizontal"
        case .attendance: return "person.badge.clock"
        case .emptyRoom: return "building.2"
        case .notification: return "bell"
        case .library: return "book"
        case .campusCard: return "creditcard"
        case .scoreReport: return "doc.text"
        case .judge: return "checkmark.seal"
        case .gmis: return "graduationcap"
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
