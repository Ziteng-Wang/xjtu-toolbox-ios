import SwiftUI

struct CurriculumScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var currentTerm = ""
    @State private var completedCredits = 0.0
    @State private var completedCourses = 0
    @State private var message = ""
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var showBrowser = false
    @State private var browserURL = AppConstants.URLS.curriculumOverviewURL
    @State private var lastUpdatedAt: Date?

    private static let updateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    var body: some View {
        Group {
            if isLoading && !hasLoaded {
                loadingView
            } else {
                contentView
            }
        }
        .navigationTitle("培养进度")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadData() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .refreshable { await loadData() }
        .task {
            if !hasLoaded {
                await loadData()
            }
        }
        .sheet(isPresented: $showBrowser) {
            NavigationStack {
                BrowserScreen(initialURL: browserURL)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("正在加载培养进度...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 14) {
                overviewCard
                quickStatsCard
                actionCardSection

                if !message.isEmpty {
                    messageCard
                }

                tipCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollIndicators(.hidden)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("培养方案总览")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(currentTerm.isEmpty ? "当前学期暂未同步" : "当前学期：\(currentTerm)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(10)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 10) {
                overviewMetric(
                    title: "已修学分",
                    value: String(format: "%.1f", completedCredits),
                    subtitle: progressHint
                )
                overviewMetric(
                    title: "已过课程",
                    value: "\(completedCourses)",
                    subtitle: "以成绩通过为准"
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.cyan, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func overviewMetric(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var quickStatsCard: some View {
        VStack(spacing: 0) {
            infoRow(label: "学期代码", value: currentTerm.isEmpty ? "未获取" : currentTerm)
            divider
            infoRow(
                label: "最近同步",
                value: lastUpdatedAt.map { Self.updateFormatter.string(from: $0) } ?? "暂无记录"
            )
            divider
            infoRow(label: "进度状态", value: progressHint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.14))
            .frame(height: 1)
    }

    private var actionCardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("培养方案入口")
                .font(.headline)

            actionCard(
                icon: "safari",
                tint: .blue,
                title: "培养方案总览",
                subtitle: "查看课程模块与要求学分"
            ) {
                browserURL = AppConstants.URLS.curriculumOverviewURL
                showBrowser = true
            }

            actionCard(
                icon: "list.bullet.indent",
                tint: .teal,
                title: "课程组树",
                subtitle: "按层级查看培养方案结构"
            ) {
                browserURL = AppConstants.URLS.curriculumCourseTreeURL
                showBrowser = true
            }
        }
    }

    private func actionCard(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var messageCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)
                .padding(.top, 1)
            Text("本页以已同步成绩进行轻量统计，最终毕业与培养结论请以教务系统为准。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
    }

    private var progressHint: String {
        switch completedCredits {
        case 0..<40:
            return "起步阶段"
        case 40..<90:
            return "稳步推进"
        default:
            return "进度良好"
        }
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
            lastUpdatedAt = Date()
        }

        guard await loginState.ensureLogin(type: .jwxt) else {
            currentTerm = ""
            completedCourses = 0
            completedCredits = 0
            message = "未登录教务系统"
            return
        }

        if await loginState.ensureLogin(type: .jwapp),
           let jwappLogin = loginState.jwappLogin {
            do {
                let api = JWAppAPI(login: jwappLogin)
                let basis = try await api.getTimeTableBasis()
                let termScores = try await api.getGrade()
                let passed = termScores
                    .flatMap(\.scoreList)
                    .filter { score in
                        score.passFlag || (score.scoreValue ?? gradeToNumericScore(score.score) ?? 0) >= 60
                    }
                currentTerm = basis.termCode
                completedCourses = passed.count
                completedCredits = passed.reduce(0) { $0 + $1.coursePoint }
                message = ""
                return
            } catch {
                // Fallback to lightweight mode.
            }
        }

        currentTerm = DateFormatter.ymd.string(from: Date())
        completedCourses = 0
        completedCredits = 0
        message = "暂未获取到成绩数据，仍可进入培养方案页面查看。"
    }
}
