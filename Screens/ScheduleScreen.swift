import SwiftUI

private enum ScheduleSubTab: String, Hashable {
    case schedule
    case exam
    case textbook

    var title: String {
        switch self {
        case .schedule: return "课表"
        case .exam: return "考试"
        case .textbook: return "教材"
        }
    }
}

struct ScheduleScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    private let weekDays = Array(1...7)
    private let sectionCount = 11

    @State private var courses: [CourseItem] = []
    @State private var exams: [ExamItem] = []
    @State private var textbooks: [TextbookItem] = []
    @State private var currentTerm = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var selectedTab: ScheduleSubTab = .schedule
    @State private var selectedWeek = 1
    @State private var availableWeeks: [Int] = [1]
    @State private var currentWeek = 1
    @State private var selectedDay = ScheduleScreen.defaultSelectedDay
    @State private var selectedCourseDetail: SelectedCourseDetail?
    @State private var termStartDate: Date?

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    private static let examDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    private static let examAltDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    private static let examMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    private static let examDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    private static let examWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    private static var defaultSelectedDay: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    private struct SelectedCourseDetail: Identifiable {
        let id = UUID()
        let course: CourseItem
        let day: Int
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            scheduleTab
                .tabItem {
                    Label("课表", systemImage: "calendar")
                }
                .tag(ScheduleSubTab.schedule)

            examTab
                .tabItem {
                    Label("考试", systemImage: "doc.text")
                }
                .tag(ScheduleSubTab.exam)

            textbookTab
                .tabItem {
                    Label("教材", systemImage: "book.closed")
                }
                .tag(ScheduleSubTab.textbook)
        }
        .navigationTitle(selectedTab.title)
        .sheet(item: $selectedCourseDetail) { detail in
            courseDetailSheet(detail)
        }
        .task {
            if courses.isEmpty, exams.isEmpty, textbooks.isEmpty, !isLoading {
                await loadData()
            }
        }
    }

    private var scheduleTab: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !currentTerm.isEmpty {
                        HStack {
                            Text("当前学期")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(currentTerm)
                        }
                        .font(.footnote)
                    }

                    weekSelectorCard

                    if coursesInSelectedWeek.isEmpty {
                        EmptyPlaceholder(title: "本周暂无课程", subtitle: "请切换周次或下拉刷新")
                    } else {
                        let contentWidth = max(300, proxy.size.width - 24)
                        timetableGrid(containerWidth: contentWidth)
                        dayCoursePanel
                    }
                }
                .padding(12)
            }
            .refreshable { await loadData() }
        }
    }

    private var weekSelectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("周次")
                        .font(.headline)
                    Text("切换后课表与课程详情会同步更新")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(
                    text: "当前第\(currentWeek)周",
                    color: selectedWeek == currentWeek ? .blue : .gray
                )
            }

            HStack(spacing: 8) {
                Button {
                    shiftWeek(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .disabled(selectedWeek <= (availableWeeks.first ?? 1))

                Picker("选择周次", selection: $selectedWeek) {
                    ForEach(availableWeeks, id: \.self) { week in
                        Text("第\(week)周")
                            .tag(week)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    shiftWeek(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .disabled(selectedWeek >= (availableWeeks.last ?? 1))
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.blue.opacity(0.12), lineWidth: 1)
        )
    }

    private var dayCoursePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(dayTitle(selectedDay))课程详情")
                    .font(.headline)
                Spacer()
                Text(dateText(for: selectedDay))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if selectedDayCourses.isEmpty {
                Text("当天暂无课程")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(selectedDayCourses) { course in
                    Button {
                        selectedCourseDetail = SelectedCourseDetail(course: course, day: selectedDay)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course.courseName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Text("\(course.startSection)-\(course.endSection)节  \(course.teacher.isEmpty ? "任课教师待定" : course.teacher)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !course.location.isEmpty {
                                Text(course.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private var selectedDayCourses: [CourseItem] {
        coursesForDay(selectedDay)
    }

    private struct TimetableLayout {
        let periodWidth: CGFloat
        let rowHeight: CGFloat
        let headerHeight: CGFloat
        let compactMode: Bool
    }

    private func timetableLayout(for containerWidth: CGFloat) -> TimetableLayout {
        let clampedWidth = max(300, containerWidth)
        let periodWidth = min(max(clampedWidth * 0.145, 42), 58)
        let dayWidth = (clampedWidth - periodWidth) / 7
        let compactMode = dayWidth < 56
        let rowHeight: CGFloat = compactMode ? 56 : 64
        let headerHeight: CGFloat = compactMode ? 50 : 60

        return TimetableLayout(
            periodWidth: periodWidth,
            rowHeight: rowHeight,
            headerHeight: headerHeight,
            compactMode: compactMode
        )
    }

    private func timetableGrid(containerWidth: CGFloat) -> some View {
        let layout = timetableLayout(for: containerWidth)
        let totalBodyHeight = layout.rowHeight * CGFloat(sectionCount)

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                timetablePeriodHeaderCell(
                    width: layout.periodWidth,
                    height: layout.headerHeight,
                    compactMode: layout.compactMode
                )
                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        timetableDayHeaderCell(
                            day: day,
                            height: layout.headerHeight,
                            compactMode: layout.compactMode
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: layout.headerHeight)

            HStack(spacing: 0) {
                timetablePeriodColumn(layout: layout)

                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        timetableDayColumn(day: day, layout: layout)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: totalBodyHeight)
        }
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.88), Color.blue.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func timetablePeriodColumn(layout: TimetableLayout) -> some View {
        VStack(spacing: 0) {
            ForEach(1...sectionCount, id: \.self) { section in
                periodCell(
                    section,
                    width: layout.periodWidth,
                    height: layout.rowHeight,
                    compactMode: layout.compactMode
                )
            }
        }
        .frame(width: layout.periodWidth)
    }

    private func timetablePeriodHeaderCell(
        width: CGFloat,
        height: CGFloat,
        compactMode: Bool
    ) -> some View {
        VStack(spacing: 2) {
            Text("节次")
                .font(compactMode ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
        }
        .frame(width: width, height: height)
        .background(Color.secondary.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func timetableDayColumn(day: Int, layout: TimetableLayout) -> some View {
        let dayCourses = coursesForDay(day)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(1...sectionCount, id: \.self) { section in
                    dayBackgroundCell(day: day, section: section, height: layout.rowHeight)
                }
            }

            ForEach(dayCourses) { course in
                TimetableCourseCell(
                    course: course,
                    tintColor: colorForCourse(course),
                    compactMode: layout.compactMode,
                    onTap: {
                        selectedDay = day
                        selectedCourseDetail = SelectedCourseDetail(course: course, day: day)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: courseBlockHeight(for: course, rowHeight: layout.rowHeight))
                .padding(.horizontal, 1.5)
                .offset(y: courseBlockOffsetY(for: course, rowHeight: layout.rowHeight))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedDay = day }
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.4)
        )
    }

    private func dayBackgroundCell(day: Int, section: Int, height: CGFloat) -> some View {
        let stripe = section.isMultiple(of: 2) ? Color.secondary.opacity(0.03) : Color.secondary.opacity(0.018)
        let dayTint: Color
        if day == selectedDay {
            dayTint = Color.blue.opacity(0.03)
        } else if day == todayWeekday {
            dayTint = Color.cyan.opacity(0.02)
        } else {
            dayTint = .clear
        }

        return ZStack {
            stripe
            dayTint
        }
        .frame(height: height)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 0.35)
        }
    }

    private func courseBlockHeight(for course: CourseItem, rowHeight: CGFloat) -> CGFloat {
        let span = max(1, course.endSection - course.startSection + 1)
        return CGFloat(span) * rowHeight - 2
    }

    private func courseBlockOffsetY(for course: CourseItem, rowHeight: CGFloat) -> CGFloat {
        CGFloat(max(course.startSection - 1, 0)) * rowHeight + 1
    }

    private func timetableDayHeaderCell(day: Int, height: CGFloat, compactMode: Bool) -> some View {
        let isToday = day == todayWeekday
        let isSelected = day == selectedDay
        let backgroundStyle: AnyShapeStyle = isSelected
            ? AnyShapeStyle(
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            : AnyShapeStyle(isToday ? Color.blue.opacity(0.11) : Color.secondary.opacity(0.08))

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 2) {
                Text(dayTitle(day))
                    .font(compactMode ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                Text(dateText(for: day))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundStyle)
        }
        .buttonStyle(.plain)
        .frame(height: height)
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func periodCell(_ section: Int, width: CGFloat, height: CGFloat, compactMode: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(section)")
                .font(compactMode ? .subheadline.weight(.semibold) : .headline)
            if let classTime = XJTUTime.classTime(section: section) {
                Text("\(classTime.start)\n\(classTime.end)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(width: width, height: height)
        .background(Color.secondary.opacity(0.06))
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func shiftWeek(by offset: Int) {
        guard let currentIndex = availableWeeks.firstIndex(of: selectedWeek) else {
            return
        }
        let target = min(max(currentIndex + offset, 0), max(availableWeeks.count - 1, 0))
        selectedWeek = availableWeeks[target]
    }

    private var courseColorMap: [String: Color] {
        let uniqueKeys = Array(Set(coursesInSelectedWeek.map(courseColorKey(for:)))).sorted()
        guard !uniqueKeys.isEmpty else {
            return [:]
        }

        let total = Double(uniqueKeys.count)
        var map: [String: Color] = [:]
        for (index, key) in uniqueKeys.enumerated() {
            let hue = Double(index) / total
            let saturation = 0.52 + Double(index % 3) * 0.08
            let brightness = 0.92 - Double(index % 2) * 0.08
            map[key] = Color(hue: hue, saturation: saturation, brightness: brightness)
        }
        return map
    }

    private func courseColorKey(for course: CourseItem) -> String {
        if !course.courseCode.isEmpty {
            return course.courseCode
        }
        return "\(course.courseName)|\(course.teacher)|\(course.location)"
    }

    private func colorForCourse(_ course: CourseItem) -> Color {
        let key = courseColorKey(for: course)
        if let color = courseColorMap[key] {
            return color
        }
        return .blue
    }

    private func courseDetailSheet(_ detail: SelectedCourseDetail) -> some View {
        NavigationStack {
            List {
                Section("课程信息") {
                    courseDetailRow("课程名", detail.course.courseName)
                    courseDetailRow("课程代码", detail.course.courseCode.isEmpty ? "暂无" : detail.course.courseCode)
                    courseDetailRow("课程类型", detail.course.courseType.isEmpty ? "暂无" : detail.course.courseType)
                }

                Section("上课安排") {
                    courseDetailRow("星期", dayTitle(detail.day))
                    courseDetailRow("节次", "\(detail.course.startSection)-\(detail.course.endSection)节")
                    courseDetailRow("周次", weekSummary(for: detail.course))
                    courseDetailRow("教师", detail.course.teacher.isEmpty ? "暂无" : detail.course.teacher)
                    courseDetailRow("教室", detail.course.location.isEmpty ? "待定" : detail.course.location)
                }
            }
            .navigationTitle("课程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        selectedCourseDetail = nil
                    }
                }
            }
        }
    }

    private func courseDetailRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 18)
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }

    private func weekSummary(for course: CourseItem) -> String {
        let weeks = course.weeks()
        guard !weeks.isEmpty else {
            return "全学期"
        }
        return "\(compressedWeekText(from: weeks))周"
    }

    private func compressedWeekText(from weeks: [Int]) -> String {
        let sortedWeeks = Array(Set(weeks)).sorted()
        guard var start = sortedWeeks.first else {
            return ""
        }

        var end = start
        var parts: [String] = []

        for week in sortedWeeks.dropFirst() {
            if week == end + 1 {
                end = week
            } else {
                parts.append(start == end ? "\(start)" : "\(start)-\(end)")
                start = week
                end = week
            }
        }
        parts.append(start == end ? "\(start)" : "\(start)-\(end)")
        return parts.joined(separator: ", ")
    }

    private var examTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !errorMessage.isEmpty {
                    subpageMessageCard(message: errorMessage, isError: true)
                } else if !currentTerm.isEmpty {
                    subpageMessageCard(message: "当前学期：\(currentTerm)", isError: false)
                }

                examSummaryCard

                if sortedExams.isEmpty {
                    emptyExamCard
                } else {
                    ForEach(sortedExams) { exam in
                        examCard(exam)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollIndicators(.hidden)
        .refreshable { await loadData() }
    }

    private var textbookTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !errorMessage.isEmpty {
                    subpageMessageCard(message: errorMessage, isError: true)
                } else if !currentTerm.isEmpty {
                    subpageMessageCard(message: "当前学期：\(currentTerm)", isError: false)
                }

                textbookSummaryCard

                if sortedTextbooks.isEmpty {
                    emptyTextbookCard
                } else {
                    ForEach(sortedTextbooks) { item in
                        textbookCard(item)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollIndicators(.hidden)
        .refreshable { await loadData() }
    }

    private var examSummaryCard: some View {
        let upcomingCount = sortedExams.filter {
            if case .upcoming = examState(for: $0) { return true }
            if case .today = examState(for: $0) { return true }
            return false
        }.count
        let todayCount = sortedExams.filter {
            if case .today = examState(for: $0) { return true }
            return false
        }.count
        let finishedCount = sortedExams.filter {
            if case .finished = examState(for: $0) { return true }
            return false
        }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("考试安排", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                Text("\(sortedExams.count) 场")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                summaryMetric(title: "待考", value: "\(upcomingCount)", color: .blue)
                summaryMetric(title: "今天", value: "\(todayCount)", color: .orange)
                summaryMetric(title: "已考", value: "\(finishedCount)", color: .gray)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var emptyExamCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("暂无考试安排")
                .font(.subheadline.weight(.medium))
            Text("下拉可刷新最新安排")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func examCard(_ exam: ExamItem) -> some View {
        let state = examState(for: exam)
        let accentColor = examAccentColor(for: state)
        let date = parsedExamDate(exam.examDate)
        let monthText = date.map { Self.examMonthFormatter.string(from: $0) } ?? "待定"
        let dayText = date.map { Self.examDayFormatter.string(from: $0) } ?? "日期"
        let weekdayText = date.map { Self.examWeekdayFormatter.string(from: $0) } ?? ""
        let courseName = exam.courseName.isEmpty ? "未知课程" : exam.courseName
        let location = exam.location.isEmpty ? "地点待定" : exam.location
        let time = exam.examTime.isEmpty ? "时间待定" : exam.examTime

        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(monthText)
                    .font(.caption.weight(.semibold))
                Text(dayText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                if !weekdayText.isEmpty {
                    Text(weekdayText)
                        .font(.caption2)
                        .foregroundStyle(accentColor.opacity(0.78))
                }
            }
            .frame(width: 74)
            .padding(.vertical, 14)
            .foregroundStyle(accentColor)
            .background(accentColor.opacity(0.1))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(courseName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        if !exam.courseCode.isEmpty {
                            Text(exam.courseCode)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    examBadge(for: state)
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !exam.seatNumber.isEmpty {
                        Text("· 座位 \(exam.seatNumber)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.22), lineWidth: 1)
        )
    }

    private func examBadge(for state: ExamTimelineState) -> some View {
        let text: String
        let color: Color

        switch state {
        case .today:
            text = "今天"
            color = .orange
        case .upcoming(let days):
            text = days <= 7 ? "\(days)天后" : "待考"
            color = .blue
        case .finished:
            text = "已结束"
            color = .gray
        case .unknown:
            text = "待定"
            color = .secondary
        }

        return Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.13), in: Capsule())
    }

    private var textbookSummaryCard: some View {
        let availableCount = sortedTextbooks.filter { $0.hasSubstantiveTextbook }.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("教材信息", systemImage: "books.vertical")
                    .font(.headline)
                Spacer()
                Text("\(sortedTextbooks.count) 门")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                summaryMetric(title: "有教材", value: "\(availableCount)", color: .blue)
                summaryMetric(title: "待补录", value: "\(max(sortedTextbooks.count - availableCount, 0))", color: .gray)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var emptyTextbookCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("暂无教材信息")
                .font(.subheadline.weight(.medium))
            Text("本学期可能尚未录入教材")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func textbookCard(_ item: TextbookItem) -> some View {
        let hasTextbook = item.hasSubstantiveTextbook
        let courseName = item.courseName.isEmpty ? "未知课程" : item.courseName

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.subheadline)
                    .foregroundStyle(hasTextbook ? Color.blue : Color.secondary)
                    .frame(width: 30, height: 30)
                    .background(
                        (hasTextbook ? Color.blue : Color.secondary)
                            .opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(courseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(hasTextbook ? Color.primary : Color.secondary)
                        .lineLimit(2)

                    if hasTextbook {
                        Text(item.displayTextbookName.isEmpty ? "教材名称待补充" : "《\(item.displayTextbookName)》")
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    } else {
                        Text("暂无教材信息")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)
            }

            if hasTextbook {
                if !item.cleanedAuthor.isEmpty {
                    detailLine(icon: "person", text: "\(item.cleanedAuthor) 著")
                }

                let publication = [item.cleanedPublisher, item.cleanedEdition]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !publication.isEmpty {
                    detailLine(icon: "building.2", text: publication)
                }

                if !item.cleanedISBN.isEmpty {
                    Text("ISBN \(item.cleanedISBN)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke((hasTextbook ? Color.blue : Color.secondary).opacity(0.16), lineWidth: 1)
        )
    }

    private func detailLine(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func summaryMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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

    private func subpageMessageCard(message: String, isError: Bool) -> some View {
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

    private var sortedExams: [ExamItem] {
        var seen: Set<String> = []
        let deduplicated = exams.filter { exam in
            let key = "\(exam.courseName)|\(exam.examDate)|\(exam.examTime)"
            return seen.insert(key).inserted
        }

        return deduplicated.sorted { lhs, rhs in
            let lhsDate = parsedExamDate(lhs.examDate)
            let rhsDate = parsedExamDate(rhs.examDate)

            switch (lhsDate, rhsDate) {
            case let (l?, r?):
                if l != r { return l < r }
                return lhs.examTime < rhs.examTime
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.courseName < rhs.courseName
            }
        }
    }

    private var sortedTextbooks: [TextbookItem] {
        textbooks.sorted { lhs, rhs in
            if lhs.hasSubstantiveTextbook != rhs.hasSubstantiveTextbook {
                return lhs.hasSubstantiveTextbook && !rhs.hasSubstantiveTextbook
            }
            return lhs.courseName < rhs.courseName
        }
    }

    private enum ExamTimelineState {
        case finished
        case today
        case upcoming(days: Int)
        case unknown
    }

    private func examState(for exam: ExamItem) -> ExamTimelineState {
        guard let date = parsedExamDate(exam.examDate) else {
            return .unknown
        }

        let today = Calendar.current.startOfDay(for: Date())
        let examDay = Calendar.current.startOfDay(for: date)
        let days = Calendar.current.dateComponents([.day], from: today, to: examDay).day ?? 0

        if days == 0 {
            return .today
        }
        if days > 0 {
            return .upcoming(days: days)
        }
        return .finished
    }

    private func examAccentColor(for state: ExamTimelineState) -> Color {
        switch state {
        case .today:
            return .orange
        case .upcoming:
            return .blue
        case .finished:
            return .secondary
        case .unknown:
            return .gray
        }
    }

    private func parsedExamDate(_ raw: String) -> Date? {
        if let date = Self.examDateFormatter.date(from: raw) {
            return date
        }
        if let date = Self.examAltDateFormatter.date(from: raw) {
            return date
        }
        return DateFormatter.ymd.date(from: raw)
    }

    private var todayWeekday: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    private var coursesInSelectedWeek: [CourseItem] {
        courses.filter { course in
            let bits = course.weekBits.filter { $0 == "0" || $0 == "1" }
            if bits.isEmpty {
                return true
            }
            return course.isInWeek(selectedWeek)
        }
    }

    private func dayTitle(_ day: Int) -> String {
        switch day {
        case 1: return "周一"
        case 2: return "周二"
        case 3: return "周三"
        case 4: return "周四"
        case 5: return "周五"
        case 6: return "周六"
        default: return "周日"
        }
    }

    private func dateText(for day: Int) -> String {
        guard let termStartDate else {
            return ""
        }

        let dayOffset = (selectedWeek - 1) * 7 + (day - 1)
        guard let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: termStartDate) else {
            return ""
        }
        return Self.monthDayFormatter.string(from: date)
    }

    private func coursesForDay(_ day: Int) -> [CourseItem] {
        coursesInSelectedWeek
            .filter { course in
                course.dayOfWeek == day
            }
            .sorted {
                if $0.startSection != $1.startSection {
                    return $0.startSection < $1.startSection
                }
                if $0.endSection != $1.endSection {
                    return $0.endSection < $1.endSection
                }
                return $0.courseName < $1.courseName
            }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        guard await loginState.ensureLogin(type: .jwxt),
              let login = loginState.jwxtLogin else {
            errorMessage = "未登录教务系统，请先登录"
            return
        }

        do {
            let api = ScheduleAPI(login: login)
            let term = try await api.getCurrentTerm()
            let schedule = try await api.getSchedule(termCode: term)
            let examList = try await api.getExamSchedule(termCode: term)
            let books = try await api.getTextbooks(studentID: loginState.activeUsername, termCode: term)
            let startDate = try? await api.getStartOfTerm(termCode: term)

            currentTerm = term
            courses = schedule
            exams = examList
            textbooks = books
            termStartDate = startDate
            updateWeekState(with: schedule, termStartDate: startDate)
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateWeekState(with schedule: [CourseItem], termStartDate: Date?) {
        let maxWeek = max(1, schedule.map(maxWeek(of:)).max() ?? 1)
        availableWeeks = Array(1...maxWeek)

        let inferred = inferredCurrentWeek(maxWeek: maxWeek, termStartDate: termStartDate)
        currentWeek = inferred

        if !availableWeeks.contains(selectedWeek) {
            selectedWeek = inferred
        }
    }

    private func maxWeek(of course: CourseItem) -> Int {
        let bits = course.weekBits.filter { $0 == "0" || $0 == "1" }
        if !bits.isEmpty {
            return bits.count
        }
        return course.weeks().max() ?? 0
    }

    private func inferredCurrentWeek(maxWeek: Int, termStartDate: Date?) -> Int {
        guard let termStartDate else {
            return 1
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: termStartDate)
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let week = days >= 0 ? (days / 7 + 1) : 1
        return min(max(1, week), maxWeek)
    }
}

private struct TimetableCourseCell: View {
    let course: CourseItem
    let tintColor: Color
    let compactMode: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GeometryReader { proxy in
                let tallCard = proxy.size.height >= (compactMode ? 88 : 102)
                let displayLocation = course.location.isEmpty ? "教室待定" : course.location

                VStack(alignment: .leading, spacing: compactMode ? 3 : 4) {
                    Text(course.courseName)
                        .font(compactMode ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                        .lineLimit(tallCard ? 3 : 2)
                        .minimumScaleFactor(0.82)
                        .multilineTextAlignment(.leading)

                    Text(displayLocation)
                        .font(compactMode ? .caption : .footnote)
                        .foregroundStyle(Color.primary.opacity(0.78))
                        .lineLimit(tallCard ? 2 : 1)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, compactMode ? 4 : 6)
                .padding(.vertical, compactMode ? 4 : 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .background(
            LinearGradient(
                colors: [tintColor.opacity(0.34), tintColor.opacity(0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: compactMode ? 8 : 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compactMode ? 8 : 10, style: .continuous)
                .stroke(tintColor.opacity(0.55), lineWidth: 0.7)
        )
        .shadow(color: tintColor.opacity(0.14), radius: 2, y: 1)
        .accessibilityLabel("\(course.courseName)，\(course.location)")
    }
}

private extension TextbookItem {
    var cleanedTextbookName: String {
        textbookName
            .replacingOccurrences(of: "&nbsp;", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayTextbookName: String {
        let raw = cleanedTextbookName
        if raw == "无教材" {
            return ""
        }
        return raw
    }

    var cleanedAuthor: String {
        author
            .replacingOccurrences(of: "&nbsp;", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedPublisher: String {
        publisher
            .replacingOccurrences(of: "&nbsp;", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedEdition: String {
        edition
            .replacingOccurrences(of: "&nbsp;", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedISBN: String {
        let raw = isbn
            .replacingOccurrences(of: "&nbsp;", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("978000000000") {
            return ""
        }
        return raw
    }

    var hasSubstantiveTextbook: Bool {
        let name = cleanedTextbookName
        guard name != "无教材" else {
            return false
        }
        let hasName = name.count >= 2
        let hasISBNDigits = cleanedISBN.contains { $0.isNumber }
        let hasAuthor = cleanedAuthor.count >= 2
        return hasName || hasISBNDigits || hasAuthor
    }
}
