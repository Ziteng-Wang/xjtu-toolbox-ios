import SwiftUI

@main
struct XJTUToolboxIOSApp: App {
    @StateObject private var loginState = AppLoginState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(loginState)
                .task {
                    await loginState.bootstrap()
                }
        }
    }
}
