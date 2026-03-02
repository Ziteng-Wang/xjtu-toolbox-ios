import SwiftUI

@main
struct XJTUToolboxIOSApp: App {
    @StateObject private var loginState = AppLoginState()

    var body: some Scene {
        WindowGroup {
            AppEntryView()
                .environmentObject(loginState)
        }
    }
}

private struct AppEntryView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @State private var bootstrapped = false

    var body: some View {
        Group {
            if !bootstrapped {
                ZStack {
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("正在初始化...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if loginState.isLoggedIn {
                RootTabView()
            } else {
                LoginSheetView(allowDismiss: false)
            }
        }
        .task {
            guard !bootstrapped else { return }
            await loginState.bootstrap()
            bootstrapped = true
        }
    }
}
