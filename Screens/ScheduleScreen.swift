import SwiftUI

struct ScheduleScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var courses: [CourseItem] = []
    @State private var exams: [ExamItem] = []
    @State private var textbooks: [TextbookItem] = []
    @State private var currentTerm = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if currentTerm.isEmpty == false {
                Section("当前学期") {
                    Text(currentTerm)
                }
            }

            Section("课表") {
                if courses.isEmpty {
                    EmptyPlaceholder(title: "暂无课表", subtitle: "下拉刷新或检查登录状态")
                } else {
                    ForEach(courses) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.courseName)
                                .font(.headline)
                            Text("\(item.teacher) · 周\(item.dayOfWeek) 第\(item.startSection)-\(item.endSection)节")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !item.location.isEmpty {
                                Text(item.location)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("考试") {
                if exams.isEmpty {
                    Text("暂无考试安排")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(exams) { exam in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exam.courseName)
                                .font(.headline)
                            Text("\(exam.examDate) \(exam.examTime)")
                                .font(.subheadline)
                            Text("\(exam.location) 座位: \(exam.seatNumber)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("教材") {
                if textbooks.isEmpty {
                    Text("暂无教材信息")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(textbooks) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.courseName)
                                .font(.headline)
                            Text(item.textbookName)
                                .font(.subheadline)
                            if !item.author.isEmpty || !item.publisher.isEmpty {
                                Text("\(item.author) \(item.publisher)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("课表 / 考试")
        .refreshable { await loadData() }
        .task {
            if courses.isEmpty, !isLoading {
                await loadData()
            }
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

            currentTerm = term
            courses = schedule
            exams = examList
            textbooks = books
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
