import SwiftUI

struct LoginSheetView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var loginType: LoginType = .jwxt
    @State private var isLoading = false
    @State private var message = ""
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    TextField("学号 / 手机号", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        if showPassword {
                            TextField("统一认证密码", text: $password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("统一认证密码", text: $password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Button(showPassword ? "隐藏" : "显示") {
                            showPassword.toggle()
                        }
                        .font(.caption)
                    }
                }

                Section("登录目标") {
                    Picker("系统", selection: $loginType) {
                        ForEach(LoginType.allCases.filter { $0 != .gmis && $0 != .gste }) { type in
                            VStack(alignment: .leading) {
                                Text(type.label)
                                Text(type.description)
                                    .font(.caption)
                            }
                            .tag(type)
                        }
                    }
                }

                if !message.isEmpty {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(message.contains("成功") ? .green : .secondary)
                    }
                }

                Section {
                    Button {
                        Task { await handleLogin() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("登录")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading)
                }

                Section("说明") {
                    Text("使用西安交通大学统一身份认证登录。密码仅用于向学校官方服务发起认证，凭据与 Cookie 在本地安全存储。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("登录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            username = loginState.savedUsername
            password = loginState.savedPassword
        }
    }

    private func handleLogin() async {
        guard !username.isEmpty, !password.isEmpty else {
            message = "请输入账号和密码"
            return
        }

        isLoading = true
        message = "正在登录 \(loginType.label)..."

        await loginState.saveCredentials(username: username, password: password)
        let success = await loginState.ensureLogin(type: loginType)
        isLoading = false

        if success {
            message = "登录成功"
            try? await Task.sleep(nanoseconds: 400_000_000)
            dismiss()
        } else {
            message = "登录失败，请检查凭据或网络"
        }
    }
}
