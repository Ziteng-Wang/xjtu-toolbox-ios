import Foundation

struct Questionnaire: Identifiable, Hashable {
    var id: String { "\(JXBID)-\(WJDM)-\(PGLXDM)" }

    let BPJS: String
    let BPR: String
    let DBRS: Int
    let JSSJ: String
    let JXBID: String
    let KCH: String
    let KCM: String
    let KSSJ: String
    let PCDM: String
    let PGLXDM: String
    let PGNR: String
    let WJDM: String
    let WJMC: String
    let XNXQDM: String
}

struct QuestionnaireData: Hashable {
    let WJDM: String
    let CPR: String
    let BPR: String
    let PGNR: String
    let ZBDM: String
    let PCDM: String
    let TXDM: String
    let JXBID: String
    var DA: String
    let ZBMC: String
    let DADM: String
    var ZGDA: String
    let SFBT: String
    let DAXH: String
    let FZ: String?

    func toJSONMap() -> [String: String] {
        [
            "WJDM": WJDM,
            "CPR": CPR,
            "BPR": BPR,
            "PGNR": PGNR,
            "ZBDM": ZBDM,
            "PCDM": PCDM,
            "TXDM": TXDM,
            "JXBID": JXBID,
            "DA": DA,
            "ZBMC": ZBMC,
            "DADM": DADM,
            "ZGDA": ZGDA,
            "SFBT": SFBT,
            "DAXH": DAXH,
            "FZ": FZ ?? "",
            "SFXYTJFJXX": "",
            "FJXXSFBT": "",
            "FJXX": ""
        ]
    }
}

struct QuestionnaireOptionData: Hashable {
    let ZBDM: String
    let ZBMC: String
    let DADM: String
    let DA: String
    let TXDM: String
    let DAPX: String
    let FZ: String
}

final class JudgeAPI {
    private let login: JwxtLogin
    private var cachedTerm: String?

    init(login: JwxtLogin) {
        self.login = login
    }

    func getCurrentTerm() async throws -> String {
        let setting = "[{\"name\":\"CSDM\",\"value\":\"PJGLPJSJ\",\"builder\":\"equal\",\"linkOpt\":\"AND\"},{\"name\":\"ZCSDM\",\"value\":\"PJXNXQ\",\"builder\":\"m_value_equal\",\"linkOpt\":\"AND\"}]"
        let response = try await login.client.post(
            "https://jwxt.xjtu.edu.cn/jwapp/sys/wspjyyapp/modules/xspj/cxxtcs.do",
            form: ["setting": setting]
        )

        let root = try jsonObject(response.data)
        let rows = (((root["datas"] as? [String: Any])?["cxxtcs"] as? [String: Any])?["rows"] as? [[String: Any]]) ?? []
        let term = rows.first?.string("CSZA") ?? ""
        cachedTerm = term
        return term
    }

    func getQuestionnaires(type: String, term: String, finished: Bool) async throws -> [Questionnaire] {
        let response = try await login.client.post(
            "https://jwxt.xjtu.edu.cn/jwapp/sys/wspjyyapp/modules/xspj/cxdwpj.do",
            form: [
                "PGLXDM": type,
                "SFPG": finished ? "1" : "0",
                "SFKF": "1",
                "SFFB": "1",
                "XNXQDM": term
            ]
        )

        let root = try jsonObject(response.data)
        let rows = (((root["datas"] as? [String: Any])?["cxdwpj"] as? [String: Any])?["rows"] as? [[String: Any]]) ?? []

        return rows.map { obj in
            Questionnaire(
                BPJS: obj.string("BPJS"),
                BPR: obj.string("BPR"),
                DBRS: obj.int("DBRS"),
                JSSJ: obj.string("JSSJ"),
                JXBID: obj.string("JXBID"),
                KCH: obj.string("KCH"),
                KCM: obj.string("KCM"),
                KSSJ: obj.string("KSSJ"),
                PCDM: obj.string("PCDM"),
                PGLXDM: obj.string("PGLXDM"),
                PGNR: obj.string("PGNR"),
                WJDM: obj.string("WJDM"),
                WJMC: obj.string("WJMC"),
                XNXQDM: obj.string("XNXQDM")
            )
        }
    }

    func unfinishedQuestionnaires(term: String? = nil) async throws -> [Questionnaire] {
        let target = try await resolvedTerm(term)
        async let middle = getQuestionnaires(type: "05", term: target, finished: false)
        async let end = getQuestionnaires(type: "01", term: target, finished: false)
        return try await middle + end
    }

    func finishedQuestionnaires(term: String? = nil) async throws -> [Questionnaire] {
        let target = try await resolvedTerm(term)
        async let middle = getQuestionnaires(type: "05", term: target, finished: true)
        async let end = getQuestionnaires(type: "01", term: target, finished: true)
        return try await middle + end
    }

    func getQuestionnaireData(q: Questionnaire, username: String) async throws -> [QuestionnaireData] {
        let response = try await login.client.post(
            "https://jwxt.xjtu.edu.cn/jwapp/sys/wspjyyapp/modules/wj/cxwjzb.do",
            form: [
                "WJDM": q.WJDM,
                "JXBID": q.JXBID
            ]
        )

        let root = try jsonObject(response.data)
        let rows = (((root["datas"] as? [String: Any])?["cxwjzb"] as? [String: Any])?["rows"] as? [[String: Any]]) ?? []

        return rows.map { obj in
            QuestionnaireData(
                WJDM: obj.string("WJDM"),
                CPR: username,
                BPR: q.BPR,
                PGNR: q.PGNR,
                ZBDM: obj.string("ZBDM"),
                PCDM: q.PCDM,
                TXDM: obj.string("TXDM"),
                JXBID: q.JXBID,
                DA: "",
                ZBMC: obj.string("ZBMC"),
                DADM: obj.string("DADM"),
                ZGDA: "",
                SFBT: obj.string("SFBT", default: "1"),
                DAXH: "1",
                FZ: obj["FZ"] as? String
            )
        }
    }

    func getQuestionnaireOptions(q: Questionnaire, username: String, finished: Bool = false) async throws -> [String: [QuestionnaireOptionData]] {
        let settingArray: [[String: String]] = [
            ["name": "BPR", "value": q.BPR, "linkOpt": "AND", "builder": "equal"],
            ["name": "CPR", "value": username, "linkOpt": "AND", "builder": "equal"],
            ["name": "JXBID", "value": q.JXBID, "linkOpt": "AND", "builder": "equal"],
            ["name": "PGNR", "value": q.PGNR, "linkOpt": "AND", "builder": "equal"],
            ["name": "WJDM", "value": q.WJDM, "linkOpt": "AND", "builder": "equal"],
            ["name": "PCDM", "value": q.PCDM, "linkOpt": "AND", "builder": "equal"]
        ]

        let settingData = try JSONSerialization.data(withJSONObject: settingArray)
        let settingString = String(data: settingData, encoding: .utf8) ?? "[]"

        let response = try await login.client.post(
            "https://jwxt.xjtu.edu.cn/jwapp/sys/wspjyyapp/modules/wj/cxxswjzbxq.do",
            form: [
                "WJDM": q.WJDM,
                "CPR": username,
                "PCDM": q.PCDM,
                "SFPG": finished ? "1" : "0",
                "BPR": q.BPR,
                "PGNR": q.PGNR,
                "querySetting": settingString
            ]
        )

        let root = try jsonObject(response.data)
        let rows = (((root["datas"] as? [String: Any])?["cxxswjzbxq"] as? [String: Any])?["rows"] as? [[String: Any]]) ?? []

        var result: [String: [QuestionnaireOptionData]] = [:]
        for obj in rows {
            let option = QuestionnaireOptionData(
                ZBDM: obj.string("ZBDM"),
                ZBMC: obj.string("ZBMC"),
                DADM: obj.string("DADM"),
                DA: obj.string("DAFXDM"),
                TXDM: obj.string("TXDM"),
                DAPX: obj.string("DAPX"),
                FZ: obj.string("FZ")
            )
            result[option.ZBDM, default: []].append(option)
        }

        return result
    }

    func autoFillQuestionnaire(
        q: Questionnaire,
        username: String,
        score: String = "1"
    ) async throws -> [QuestionnaireData] {
        let dataList = try await getQuestionnaireData(q: q, username: username)
        let options = try await getQuestionnaireOptions(q: q, username: username, finished: false)

        return dataList.map { item in
            var mutable = item
            switch item.TXDM {
            case "01":
                let candidate = options[item.ZBDM] ?? []
                if let exact = candidate.first(where: { $0.DAPX == score }) {
                    mutable.DA = exact.DA
                } else {
                    mutable.DA = candidate.first?.DA ?? ""
                }
            case "02":
                mutable.DA = ""
                mutable.ZGDA = "老师授课认真，课程内容清晰，收获很大。"
            case "03":
                if let max = Int(item.FZ ?? ""), max > 0 {
                    mutable.DA = String(max)
                } else {
                    mutable.DA = "100"
                }
            default:
                break
            }
            return mutable
        }
    }

    func submitQuestionnaire(q: Questionnaire, data: [QuestionnaireData]) async throws -> (Bool, String) {
        let answerPayload = data.map { $0.toJSONMap() }
        let answerData = try JSONSerialization.data(withJSONObject: answerPayload)
        let answerString = String(data: answerData, encoding: .utf8) ?? "[]"

        let requestPayload: [String: Any] = [
            "WJDM": q.WJDM,
            "PCDM": q.PCDM,
            "PGLY": "1",
            "SFTJ": "1",
            "WJYSJG": answerString
        ]

        let requestData = try JSONSerialization.data(withJSONObject: requestPayload)
        let requestString = String(data: requestData, encoding: .utf8) ?? "{}"

        let response = try await login.client.post(
            "https://jwxt.xjtu.edu.cn/jwapp/sys/wspjyyapp/WspjwjController/addXsPgysjg.do",
            form: ["requestParamStr": requestString]
        )

        let root = try jsonObject(response.data)
        let code = root.string("code", default: "-1")
        let datas = root["datas"] as? [String: Any] ?? [:]
        let datasCode = datas.string("code", default: "-1")
        let msg = datas.string("msg", default: "未知错误")

        return (code == "0" && datasCode == "0", msg)
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        return dict
    }

    private func resolvedTerm(_ term: String?) async throws -> String {
        if let term {
            return term
        }
        if let cachedTerm {
            return cachedTerm
        }
        return try await getCurrentTerm()
    }
}
