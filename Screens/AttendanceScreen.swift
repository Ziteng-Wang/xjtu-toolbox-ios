import SwiftUI

struct AttendanceScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var studentInfo: [String: Any] = [:]
    @State private var stats: [CourseAttendanceStat] = []
    @State private var errorMessage = ""

    var body: some View {
        List {
            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if !studentInfo.isEmpty {
                Section("学生信息") {
                    infoRow("姓名", studentInfo["name"] as? String ?? "")
                    infoRow("学号", studentInfo["sno"] as? String ?? "")
                    infoRow("学院", studentInfo["departmentName"] as? String ?? "")
                }
            }

            Section("课程考勤统计") {
                if stats.isEmpty {
                    Text("暂无统计")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(stats) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.subjectName)
                                .font(.headline)
                            HStack {
                                Text("正常 \(item.normalCount)")
                                Text("迟到 \(item.lateCount)")
                                Text("缺勤 \(item.absenceCount)")
                                Text("请假 \(item.leaveCount)")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("考勤")
        .refreshable { await loadData() }
        .task {
            if stats.isEmpty {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard await loginState.ensureLogin(type: .attendance),
              let login = loginState.attendanceLogin else {
            errorMessage = "未登录考勤系统"
            return
        }

        do {
            let api = AttendanceAPI(login: login)
            studentInfo = try await api.getStudentInfo()
            let weekStats = try await api.getCurrentWeekStats()
            if weekStats.isEmpty {
                let records = try await api.getWaterRecords()
                stats = api.computeCourseStats(from: records)
            } else {
                stats = weekStats
            }
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
