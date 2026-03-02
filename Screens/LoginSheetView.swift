import SwiftUI

struct LoginSheetView: View {
    @EnvironmentObject private var loginState: AppLoginState
    @Environment(\.dismiss) private var dismiss

    let allowDismiss: Bool

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var message = ""
    @State private var showPassword = false
    @State private var showTermsConfirm = false

    init(allowDismiss: Bool = true) {
        self.allowDismiss = allowDismiss
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.2),
                        Color.cyan.opacity(0.12),
                        Color(uiColor: .systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        credentialsCard

                        if !message.isEmpty {
                            statusCard
                        }

                        loginButton
                        noteCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if allowDismiss {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }
                    }
                }
            }
        }
        .alert("使用条款确认", isPresented: $showTermsConfirm) {
            Button("取消", role: .cancel) {}
            Button("同意并继续") {
                Task {
                    await loginState.acceptEula()
                    await performLogin()
                }
            }
        } message: {
            Text("继续登录即表示你已阅读并同意本应用使用条款与免责声明。")
        }
        .onAppear {
            username = loginState.savedUsername
            password = loginState.savedPassword
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
            .shadow(color: Color.blue.opacity(0.25), radius: 14, y: 8)

            Text("统一身份认证")
                .font(.title2.weight(.bold))

            Text("默认登录教务系统，其他需要认证的功能会在进入时自动使用当前账号登录。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldLabel("账号")
            TextField("学号 / 手机号", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            fieldLabel("密码")
            HStack(spacing: 10) {
                Group {
                    if showPassword {
                        TextField("统一认证密码", text: $password)
                    } else {
                        SecureField("统一认证密码", text: $password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Image(systemName: message.contains("成功") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(message.contains("成功") ? Color.green : Color.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var loginButton: some View {
        Button {
            Task { await handleLogin() }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(isLoading ? "登录中..." : "登录教务系统")
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.cyan],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: Color.blue.opacity(0.22), radius: 12, y: 6)
        .disabled(isLoading)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("登录说明")
                .font(.subheadline.weight(.semibold))
            Text("密码仅用于向学校官方服务发起认证，凭据和 Cookie 仅保存在本机。点击登录即表示你同意应用使用条款与免责声明。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @MainActor
    private func handleLogin() async {
        guard loginState.eulaAccepted else {
            showTermsConfirm = true
            return
        }
        await performLogin()
    }

    @MainActor
    private func performLogin() async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty, !trimmedPassword.isEmpty else {
            message = "请输入账号和密码"
            return
        }

        username = trimmedUsername
        password = trimmedPassword
        isLoading = true
        message = "正在登录教务系统..."

        await loginState.saveCredentials(username: trimmedUsername, password: trimmedPassword)
        let success = await loginState.ensureLogin(type: .jwxt)
        isLoading = false

        if success {
            message = "登录成功"
            try? await Task.sleep(nanoseconds: 450_000_000)
            dismiss()
        } else {
            if let detail = loginState.lastLoginError, !detail.isEmpty {
                message = "登录失败：\(detail)"
            } else {
                message = "登录失败，请检查凭据或网络"
            }
        }
    }
}
