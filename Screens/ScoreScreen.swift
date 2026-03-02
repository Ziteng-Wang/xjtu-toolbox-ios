import SwiftUI
import OSLog

struct ScoreScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    private let allTermCode = "__all_terms__"
    private let logger = Logger(subsystem: "com.xjtu.toolbox.ios", category: "ScoreScreen")

    @State private var terms: [TermScore] = []
    @State private var selectedTermCode = "__all_terms__"
    @State private var expandedTermCodes: Set<String> = []
    @State private var selectedCourseIDs: Set<String> = []
    @State private var searchQuery = ""
    @State private var isCourseSelectionMode = false
    @State private var isTermPickerPresented = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var hasRestoredCachedTerms = false
    @State private var termGPAIndex: [String: GPAInfo] = [:]
    @State private var expandedCourseID: String?
    @State private var courseDetails: [String: ScoreDetail] = [:]
    @State private var detailErrors: [String: String] = [:]
    @State private var detailLoadingCourseID: String?

    var body: some View {
        Group {
            if isLoading && terms.isEmpty {
                loadingView
            } else {
                contentView
            }
        }
        .navigationTitle("成绩查询")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .refreshable { await loadData() }
        .task {
            if terms.isEmpty {
                restoreCachedTermsIfNeeded()
                await loadData()
            }
        }
        .sheet(isPresented: $isTermPickerPresented) {
            termPickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("正在加载成绩数据...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !errorMessage.isEmpty {
                    messageCard(errorMessage, isError: true)
                }

                overviewCard
                controlCard
                searchCard

                if !visibleCourses.isEmpty {
                    performanceCard
                }

                if sortedVisibleTerms.isEmpty {
                    emptyCard
                } else {
                    ForEach(sortedVisibleTerms) { term in
                        termCard(term)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollIndicators(.hidden)
    }

    private var overviewCard: some View {
        let info = displayGPAInfo
        let cardTint = isCourseSelectionMode ? Color.teal : Color.blue
        let courseCount = isCourseSelectionMode ? selectedCourseIDs.count : (info?.courseCount ?? visibleCourses.count)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isCourseSelectionMode ? "选课均分" : "成绩概览")
                        .font(.headline)
                    Text(isCourseSelectionMode ? "已选 \(selectedCourseIDs.count) 门课程" : selectedTermLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isCourseSelectionMode ? "checklist.checked" : "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(cardTint)
                    .padding(8)
                    .background(cardTint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 0) {
                overviewMetric(value: metricText(info?.gpa, format: "%.3f"), label: "GPA")
                verticalDivider
                overviewMetric(value: metricText(info?.averageScore, format: "%.2f"), label: "均分")
                verticalDivider
                overviewMetric(value: "\(courseCount)", label: "课程")
                verticalDivider
                overviewMetric(value: metricText(info?.totalCredits, format: "%.1f"), label: "学分")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardTint.opacity(0.16), lineWidth: 1)
        )
    }

    private func overviewMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 32)
    }

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                termPickerMenu
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCourseSelectionMode.toggle()
                    }
                } label: {
                    Label(
                        isCourseSelectionMode ? "退出选课" : "选课算均分",
                        systemImage: isCourseSelectionMode ? "checkmark.circle" : "plus.circle"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((isCourseSelectionMode ? Color.teal : Color.blue).opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }

            if isCourseSelectionMode {
                HStack(spacing: 8) {
                    Text("已选 \(selectedCourseIDs.count) 门")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("全选当前") {
                        let ids = visibleCourses.map(\.id)
                        selectedCourseIDs.formUnion(ids)
                    }
                    .font(.caption.weight(.semibold))

                    Button("清空选择") {
                        selectedCourseIDs.removeAll()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var termPickerMenu: some View {
        Button {
            isTermPickerPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption.weight(.semibold))
                Text(selectedTermLabel)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var termPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    termPickerRow(
                        title: "全部学期",
                        subtitle: "汇总所有学期成绩",
                        termCode: allTermCode
                    )

                    ForEach(sortedTerms) { term in
                        termPickerRow(
                            title: termDisplayName(term),
                            subtitle: term.termCode,
                            termCode: term.termCode
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("选择学期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        isTermPickerPresented = false
                    }
                }
            }
        }
    }

    private func termPickerRow(title: String, subtitle: String, termCode: String) -> some View {
        let selected = selectedTermCode == termCode

        return Button {
            selectTerm(termCode)
            isTermPickerPresented = false
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.blue : Color.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.blue.opacity(0.12) : Color(uiColor: .secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var searchCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索课程（模糊匹配）", text: $searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var performanceCard: some View {
        let stats = visibleCourseStats

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("通过情况", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.headline)
                Spacer()
                Text("\(visibleCourses.count) 门课程")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                metricItem("优秀", "\(stats.excellentCount)", .green)
                metricItem("及格率", "\(Int(stats.passRate * 100))%", .blue)
                metricItem("不及格", "\(stats.failCount)", .red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func metricItem(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func termCard(_ term: TermScore) -> some View {
        let expanded = selectedTermCode != allTermCode || expandedTermCodes.contains(term.termCode)
        let info = termGPAIndex[term.termCode] ?? calculateGPA(for: term.scoreList)

        return VStack(alignment: .leading, spacing: 10) {
            if selectedTermCode == allTermCode {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedTermCodes.contains(term.termCode) {
                            expandedTermCodes.remove(term.termCode)
                        } else {
                            expandedTermCodes.insert(term.termCode)
                        }
                    }
                } label: {
                    HStack {
                        Text(termDisplayName(term))
                            .font(.headline)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text(termDisplayName(term))
                    .font(.headline)
            }

            HStack(spacing: 8) {
                smallInfo("GPA \(metricText(info.gpa, format: "%.3f"))")
                smallInfo("均分 \(metricText(info.averageScore, format: "%.2f"))")
                smallInfo("学分 \(metricText(info.totalCredits, format: "%.1f"))")
            }

            if expanded {
                ForEach(term.scoreList) { score in
                    scoreRow(score)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func smallInfo(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func scoreRow(_ score: ScoreItem) -> some View {
        let selected = selectedCourseIDs.contains(score.id)
        let expanded = expandedCourseID == score.id

        if isCourseSelectionMode {
            Button {
                if selected {
                    selectedCourseIDs.remove(score.id)
                } else {
                    selectedCourseIDs.insert(score.id)
                }
            } label: {
                scoreRowContent(score, isSelected: selected, showsExpandIndicator: false, isExpanded: false)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                scoreRowContent(score, isSelected: false, showsExpandIndicator: true, isExpanded: expanded)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleDetail(for: score)
                    }

                if expanded {
                    detailSection(courseID: score.id)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: expanded)
        }
    }

    private func scoreRowContent(
        _ score: ScoreItem,
        isSelected: Bool,
        showsExpandIndicator: Bool,
        isExpanded: Bool
    ) -> some View {
        let tint = scoreColor(score)

        return HStack(spacing: 10) {
            if isCourseSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary)
            }

            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: scoreIcon(score))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(score.courseName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text("学分 \(String(format: "%.1f", score.coursePoint))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(score.score)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                if let gpa = score.gpa, gpa > 0 {
                    Text(String(format: "GPA %.1f", gpa))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if showsExpandIndicator {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isCourseSelectionMode && isSelected ? Color.blue.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func detailSection(courseID: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.top, 6)

            if detailLoadingCourseID == courseID {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载成绩构成...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            } else if let detail = courseDetails[courseID] {
                detailMetaGrid(detail)

                if detail.itemList.isEmpty {
                    Text("该课程暂无分项成绩")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                } else {
                    Text("分项成绩")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    VStack(spacing: 8) {
                        ForEach(detail.itemList) { item in
                            scoreDetailRow(item)
                        }
                    }
                }
            } else if let error = detailErrors[courseID] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.vertical, 4)
            } else {
                Text("未获取到成绩构成数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func detailMetaGrid(_ detail: ScoreDetail) -> some View {
        var metrics: [(String, String)] = [
            ("绩点", String(format: "%.1f", detail.gpa)),
            ("学分", String(format: "%.1f", detail.coursePoint))
        ]
        if !detail.examType.isEmpty {
            metrics.append(("类型", detail.examType))
        }
        if let major = detail.majorFlag, !major.isEmpty {
            metrics.append(("性质", major))
        }

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 3) {
                    Text(item.1)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.0)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            }
        }
    }

    private func scoreDetailRow(_ item: ScoreDetailItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.itemName.isEmpty ? "未命名分项" : item.itemName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Text(percentText(item.itemPercent))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)

                if let scoreValue = item.itemScoreValue {
                    ProgressView(value: min(max(scoreValue / 100, 0), 1))
                        .tint(.blue)
                        .frame(maxWidth: .infinity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 8)
                }

                Text(item.itemScore.isEmpty ? "—" : item.itemScore)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scoreColorForRaw(item.itemScore))
                    .frame(width: 46, alignment: .trailing)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无成绩数据" : "未匹配到课程")
                .font(.subheadline.weight(.medium))
            Text(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请下拉刷新或检查登录状态" : "请修改搜索关键词或切换学期")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func messageCard(_ message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle")
                .foregroundStyle(isError ? Color.red : Color.blue)
            Text(message)
                .font(.footnote)
                .foregroundStyle(isError ? Color.red : Color.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((isError ? Color.red : Color.blue).opacity(0.1))
        )
    }

    @MainActor
    private func loadData() async {
        guard !isLoading else { return }

        let loadStartedAt = Date()
        let hadLocalData = !terms.isEmpty
        isLoading = true
        defer { isLoading = false }

        let loginStartedAt = Date()
        guard await loginState.ensureLogin(type: .jwapp),
              let login = loginState.jwappLogin else {
            errorMessage = "未登录移动教务"
            logger.error("score load failed: jwapp login unavailable")
            return
        }
        let loginElapsedMS = Int(Date().timeIntervalSince(loginStartedAt) * 1000)

        do {
            let api = JWAppAPI(login: login)
            let fetchStartedAt = Date()
            let termScores = try await api.getGrade()
            let fetchElapsedMS = Int(Date().timeIntervalSince(fetchStartedAt) * 1000)

            let applyStartedAt = Date()
            applyTermScores(termScores)
            persistCachedTerms(termScores)
            errorMessage = ""

            let applyElapsedMS = Int(Date().timeIntervalSince(applyStartedAt) * 1000)
            let totalElapsedMS = Int(Date().timeIntervalSince(loadStartedAt) * 1000)
            logger.info(
                "score load success loginMs=\(loginElapsedMS, privacy: .public) fetchMs=\(fetchElapsedMS, privacy: .public) applyMs=\(applyElapsedMS, privacy: .public) totalMs=\(totalElapsedMS, privacy: .public) cacheHit=\(hadLocalData, privacy: .public)"
            )
        } catch {
            errorMessage = hadLocalData ? "刷新失败：\(error.localizedDescription)" : error.localizedDescription
            let totalElapsedMS = Int(Date().timeIntervalSince(loadStartedAt) * 1000)
            logger.error(
                "score load failed totalMs=\(totalElapsedMS, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func applyTermScores(_ termScores: [TermScore]) {
        terms = termScores
        termGPAIndex = termScores.reduce(into: [:]) { partialResult, term in
            partialResult[term.termCode] = calculateGPA(for: term.scoreList)
        }

        if selectedTermCode != allTermCode,
           !termScores.contains(where: { $0.termCode == selectedTermCode }) {
            selectedTermCode = allTermCode
        }

        let availableTermCodes = Set(termScores.map(\.termCode))
        expandedTermCodes = expandedTermCodes.intersection(availableTermCodes)
        if expandedTermCodes.isEmpty {
            expandedTermCodes = Set(termScores.map(\.termCode).sorted(by: >).prefix(1))
        }

        let availableCourseIDs = Set(termScores.flatMap(\.scoreList).map(\.id))
        selectedCourseIDs = selectedCourseIDs.intersection(availableCourseIDs)

        if let expandedCourseID,
           !availableCourseIDs.contains(expandedCourseID) {
            self.expandedCourseID = nil
        }
        courseDetails = courseDetails.filter { availableCourseIDs.contains($0.key) }
        detailErrors = detailErrors.filter { availableCourseIDs.contains($0.key) }
        if let detailLoadingCourseID,
           !availableCourseIDs.contains(detailLoadingCourseID) {
            self.detailLoadingCourseID = nil
        }
    }

    private func restoreCachedTermsIfNeeded() {
        guard !hasRestoredCachedTerms else { return }
        hasRestoredCachedTerms = true

        guard terms.isEmpty,
              let username = cacheUsername else {
            return
        }

        let key = scoreCacheKey(for: username)
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ScoreCacheSnapshot.self, from: data),
              !snapshot.terms.isEmpty else {
            return
        }

        applyTermScores(snapshot.terms)
        logger.info("score cache restore success termCount=\(snapshot.terms.count, privacy: .public)")
    }

    private func persistCachedTerms(_ termScores: [TermScore]) {
        guard let username = cacheUsername else { return }

        let snapshot = ScoreCacheSnapshot(updatedAt: Date(), terms: termScores)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: scoreCacheKey(for: username))
    }

    private var cacheUsername: String? {
        let active = loginState.activeUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if !active.isEmpty {
            return active
        }

        let saved = loginState.savedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return saved.isEmpty ? nil : saved
    }

    private func scoreCacheKey(for username: String) -> String {
        "xjtu.score.cache.\(username)"
    }

    private func selectTerm(_ termCode: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTermCode = termCode
            if termCode == allTermCode {
                if expandedTermCodes.isEmpty {
                    expandedTermCodes = Set(sortedTerms.map { $0.termCode }.prefix(1))
                }
            } else {
                expandedTermCodes = [termCode]
            }
        }
    }

    private func metricText(_ value: Double?, format: String) -> String {
        guard let value else { return "—" }
        return String(format: format, value)
    }

    private var displayGPAInfo: GPAInfo? {
        let courses = isCourseSelectionMode ? selectedCourses : visibleCourses
        guard !courses.isEmpty else { return nil }
        return calculateGPA(for: courses)
    }

    private var selectedCourses: [ScoreItem] {
        let courseMap = Dictionary(uniqueKeysWithValues: terms.flatMap(\.scoreList).map { ($0.id, $0) })
        return selectedCourseIDs.compactMap { courseMap[$0] }
    }

    private var sortedTerms: [TermScore] {
        terms.sorted { $0.termCode > $1.termCode }
    }

    private var sortedVisibleTerms: [TermScore] {
        visibleTerms.sorted { $0.termCode > $1.termCode }
    }

    private var visibleTerms: [TermScore] {
        let termsBySelection: [TermScore]
        if selectedTermCode == allTermCode {
            termsBySelection = terms
        } else {
            termsBySelection = terms.filter { $0.termCode == selectedTermCode }
        }

        let keyword = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return termsBySelection
        }

        return termsBySelection.compactMap { term in
            let filteredScores = term.scoreList.filter { score in
                matchesSearch(score, keyword: keyword)
            }
            guard !filteredScores.isEmpty else { return nil }
            return TermScore(termCode: term.termCode, termName: term.termName, scoreList: filteredScores)
        }
    }

    private var visibleCourses: [ScoreItem] {
        visibleTerms.flatMap { $0.scoreList }
    }

    private var selectedTermLabel: String {
        if selectedTermCode == allTermCode {
            return "全部学期"
        }
        return sortedTerms.first(where: { $0.termCode == selectedTermCode }).map(termDisplayName) ?? selectedTermCode
    }

    private var visibleCourseStats: (excellentCount: Int, failCount: Int, passRate: Double) {
        let courses = visibleCourses
        guard !courses.isEmpty else {
            return (0, 0, 0)
        }

        var excellent = 0
        var failed = 0
        var passed = 0

        for score in courses {
            let numeric = scoreNumeric(score)
            if let numeric, numeric >= 90 {
                excellent += 1
            }

            if score.passFlag || score.score == "通过" || (numeric ?? 0) >= 60 {
                passed += 1
            } else if numeric != nil || score.score == "不通过" {
                failed += 1
            }
        }

        let passRate = Double(passed) / Double(courses.count)
        return (excellent, failed, passRate)
    }

    private func scoreNumeric(_ score: ScoreItem) -> Double? {
        if let raw = score.scoreValue {
            return raw
        }
        return gradeToNumericScore(score.score)
    }

    private func scoreColor(_ score: ScoreItem) -> Color {
        if score.score == "通过" {
            return .blue
        }
        if score.score == "不通过" {
            return .red
        }

        guard let numeric = scoreNumeric(score) else {
            return .secondary
        }
        switch numeric {
        case 90...:
            return .green
        case 80..<90:
            return .blue
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }

    private func scoreIcon(_ score: ScoreItem) -> String {
        if score.score == "通过" || score.passFlag {
            return "checkmark"
        }
        if score.score == "不通过" {
            return "xmark"
        }
        return "graduationcap"
    }

    private func termDisplayName(_ term: TermScore) -> String {
        term.termName.isEmpty ? term.termCode : term.termName
    }

    private func matchesSearch(_ score: ScoreItem, keyword: String) -> Bool {
        let fields = [
            score.courseName,
            score.score,
            score.examType,
            score.majorFlag ?? "",
            score.examProp
        ]
        return fields.contains { field in
            field.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func toggleDetail(for course: ScoreItem) {
        let shouldExpand = expandedCourseID != course.id
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            expandedCourseID = shouldExpand ? course.id : nil
        }

        guard shouldExpand,
              courseDetails[course.id] == nil,
              detailLoadingCourseID != course.id else {
            return
        }

        Task {
            await loadDetail(courseID: course.id)
        }
    }

    @MainActor
    private func loadDetail(courseID: String) async {
        guard courseDetails[courseID] == nil else { return }

        detailErrors[courseID] = nil
        detailLoadingCourseID = courseID
        defer {
            if detailLoadingCourseID == courseID {
                detailLoadingCourseID = nil
            }
        }

        guard await loginState.ensureLogin(type: .jwapp),
              let login = loginState.jwappLogin else {
            detailErrors[courseID] = "未登录移动教务，无法获取成绩构成"
            return
        }

        do {
            let api = JWAppAPI(login: login)
            let detail = try await api.getDetail(courseID: courseID)
            courseDetails[courseID] = detail
        } catch {
            detailErrors[courseID] = "加载成绩构成失败：\(error.localizedDescription)"
        }
    }

    private func percentText(_ value: Double) -> String {
        if value <= 0 { return "0%" }
        return "\(Int((value * 100).rounded()))%"
    }

    private func scoreColorForRaw(_ rawScore: String) -> Color {
        let normalized = rawScore.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized == "通过" {
            return .blue
        }
        if normalized == "不通过" {
            return .red
        }

        guard let numeric = gradeToNumericScore(normalized) else {
            return .secondary
        }

        switch numeric {
        case 90...:
            return .green
        case 80..<90:
            return .blue
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }

    private func calculateGPA(for courses: [ScoreItem]) -> GPAInfo {
        var totalCredits = 0.0
        var weightedGPA = 0.0
        var weightedScore = 0.0
        var courseCount = 0

        for course in courses {
            let clean = course.score
                .replacingOccurrences(of: "＋", with: "+")
                .replacingOccurrences(of: "－", with: "-")
                .removingInvisibleCharacters

            if clean == "通过" || clean == "不通过" {
                continue
            }

            let apiGPA = (course.gpa ?? 0) > 0 ? course.gpa! : 0
            let mappedGPA = scoreToGPA(clean) ?? apiGPA
            let finalGPA = max(apiGPA, mappedGPA)
            let numericScore = course.scoreValue ?? gradeToNumericScore(clean) ?? 0

            let passed = course.passFlag || finalGPA > 0 || numericScore >= 60
            if !passed && course.examProp == "初修" {
                continue
            }

            totalCredits += course.coursePoint
            weightedGPA += finalGPA * course.coursePoint
            weightedScore += numericScore * course.coursePoint
            courseCount += 1
        }

        let gpa = totalCredits > 0 ? weightedGPA / totalCredits : 0
        let average = totalCredits > 0 ? weightedScore / totalCredits : 0

        return GPAInfo(
            gpa: gpa,
            averageScore: average,
            totalCredits: totalCredits,
            courseCount: courseCount
        )
    }
}

private struct ScoreCacheSnapshot: Codable {
    let updatedAt: Date
    let terms: [TermScore]
}
