import Foundation

enum LoginFlowState: Equatable {
    case requireMFA
    case requireCaptcha
    case success
    case fail
    case requireAccountChoice
}

struct LoginResult {
    let state: LoginFlowState
    let message: String
    let mfaContext: MFAContext?
    let accountChoices: [AccountChoice]

    init(
        state: LoginFlowState,
        message: String = "",
        mfaContext: MFAContext? = nil,
        accountChoices: [AccountChoice] = []
    ) {
        self.state = state
        self.message = message
        self.mfaContext = mfaContext
        self.accountChoices = accountChoices
    }
}

struct AccountChoice: Hashable {
    let name: String
    let label: String
}

enum AccountType {
    case undergraduate
    case postgraduate
}

final class MFAContext {
    let state: String
    let required: Bool

    init(state: String, required: Bool) {
        self.state = state
        self.required = required
    }
}

enum LoginType: String, CaseIterable, Identifiable {
    case attendance
    case jwxt
    case jwapp
    case ywtb
    case library
    case campusCard
    case gmis
    case gste

    var id: String { rawValue }

    var label: String {
        switch self {
        case .attendance:
            return "考勤系统"
        case .jwxt:
            return "教务系统"
        case .jwapp:
            return "移动教务"
        case .ywtb:
            return "一网通办"
        case .library:
            return "图书馆座位"
        case .campusCard:
            return "校园卡"
        case .gmis:
            return "研究生管理"
        case .gste:
            return "研究生评教"
        }
    }

    var description: String {
        switch self {
        case .attendance:
            return "本科生考勤查询"
        case .jwxt:
            return "课表 / 考试 / 教材"
        case .jwapp:
            return "成绩查询"
        case .ywtb:
            return "学期周次 / 个人信息"
        case .library:
            return "座位查询与预约"
        case .campusCard:
            return "余额与消费"
        case .gmis:
            return "研究生课表与成绩"
        case .gste:
            return "研究生评教"
        }
    }
}
