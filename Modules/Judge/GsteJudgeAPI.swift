import Foundation

struct GraduateQuestionnaire: Identifiable, Hashable {
    var id: String { "\(DATA_JXB_ID)-\(DATA_JXB_JS_ID)-\(KCBH)" }

    let ASSESSMENT: String
    let BJID: String
    let BJMC: String
    let DATA_JXB_ID: Int
    let DATA_JXB_JS_ID: Int
    let JSBH: String
    let JSXM: String
    let JXB_SJ_OK: String
    let KCBH: String
    let KCMC: String
    let KCYWMC: String
    let KKDW: String
    let LANG: String
    let SKLS_DUTY: String
    let TERMCODE: String
    let TERMNAME: String
}

struct FormQuestion: Identifiable, Hashable {
    let id: String
    let name: String
    let view: String
    let options: [FormOption]
}

struct FormOption: Identifiable, Hashable {
    let id: String
    let value: String
}

final class GsteJudgeAPI {
    private let login: GsteLogin

    init(login: GsteLogin) {
        self.login = login
    }

    func getQuestionnaires() async throws -> [GraduateQuestionnaire] {
        let response = try await login.client.get("http://gste.xjtu.edu.cn/app/sshd4Stu/list.do")
        let object = try JSONSerialization.jsonObject(with: response.data)
        guard let array = object as? [[String: Any]] else {
            throw HTTPError.invalidResponse
        }

        return array.map { obj in
            GraduateQuestionnaire(
                ASSESSMENT: obj.string("assessment"),
                BJID: obj.string("bjid"),
                BJMC: obj.string("bjmc"),
                DATA_JXB_ID: obj.int("data_jxb_id"),
                DATA_JXB_JS_ID: obj.int("data_jxb_js_id"),
                JSBH: obj.string("jsbh"),
                JSXM: obj.string("jsxm"),
                JXB_SJ_OK: obj.string("jxb_sj_ok"),
                KCBH: obj.string("kcbh"),
                KCMC: obj.string("kcmc"),
                KCYWMC: obj.string("kcywmc"),
                KKDW: obj.string("kkdw"),
                LANG: obj.string("lang"),
                SKLS_DUTY: obj.string("skls_duty"),
                TERMCODE: obj.string("termcode"),
                TERMNAME: obj.string("termname")
            )
        }
    }

    func getQuestionnaireHTML(_ q: GraduateQuestionnaire) async throws -> String {
        guard var components = URLComponents(string: "http://gste.xjtu.edu.cn/app/student/genForm.do") else {
            throw HTTPError.invalidURL
        }
        components.queryItems = [
            .init(name: "assessment", value: q.ASSESSMENT),
            .init(name: "bjid", value: q.BJID),
            .init(name: "bjmc", value: q.BJMC),
            .init(name: "data_jxb_id", value: String(q.DATA_JXB_ID)),
            .init(name: "data_jxb_js_id", value: String(q.DATA_JXB_JS_ID)),
            .init(name: "jsbh", value: q.JSBH),
            .init(name: "jsxm", value: q.JSXM),
            .init(name: "jxb_sj_ok", value: q.JXB_SJ_OK),
            .init(name: "kcbh", value: q.KCBH),
            .init(name: "kcmc", value: q.KCMC),
            .init(name: "kcywmc", value: q.KCYWMC),
            .init(name: "kkdw", value: q.KKDW),
            .init(name: "lang", value: q.LANG),
            .init(name: "skls_duty", value: q.SKLS_DUTY),
            .init(name: "termcode", value: q.TERMCODE),
            .init(name: "termname", value: q.TERMNAME)
        ]

        let response = try await login.client.get(components.url?.absoluteString ?? "")
        return response.bodyString
    }

    func parseForm(from html: String) -> (meta: [String: String], questions: [FormQuestion]) {
        // Keep parsing logic lightweight and robust with regex fallback.
        var meta: [String: String] = [:]
        var questions: [FormQuestion] = []

        if let hiddenRegex = try? NSRegularExpression(
            pattern: #"<input[^>]*type=["']hidden["'][^>]*name=["']([^"']+)["'][^>]*value=["']([^"']*)["']"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(html.startIndex..., in: html)
            for match in hiddenRegex.matches(in: html, range: range) {
                guard match.numberOfRanges > 2,
                      let keyRange = Range(match.range(at: 1), in: html),
                      let valueRange = Range(match.range(at: 2), in: html) else {
                    continue
                }
                meta[String(html[keyRange])] = String(html[valueRange])
            }
        }

        // Direct JSON object fallback from pjzbApp.form.
        if let formJSON = extractFormJSON(from: html),
           let object = try? JSONSerialization.jsonObject(with: formJSON) as? [String: Any] {
            let extracted = walkFormTree(object)
            meta.merge(extracted.meta) { _, new in new }
            questions.append(contentsOf: extracted.questions)
        }

        return (meta, questions)
    }

    func autoFill(
        questions: [FormQuestion],
        meta: [String: String],
        questionnaire: GraduateQuestionnaire,
        score: Int = 3
    ) -> [String: String] {
        var result = meta
        let labels = ["不合格", "合格", "良好", "优秀"]
        let expected = labels[max(0, min(3, score))]

        for question in questions {
            switch question.view {
            case "radio", "select":
                if let option = question.options.first(where: { $0.value.contains(expected) }) ?? question.options.first {
                    result[question.id] = option.id
                }
            case "textarea":
                result[question.id] = "无"
            case "text":
                result[question.id] = questionnaire.KCMC
            default:
                break
            }
        }

        if score == 3,
           let firstRadio = questions.first(where: { $0.view == "radio" }),
           let fallback = firstRadio.options.first(where: { $0.value.contains("良好") }) {
            result[firstRadio.id] = fallback.id
        }

        return result
    }

    func submitQuestionnaire(_ q: GraduateQuestionnaire, formData: [String: String]) async throws -> Bool {
        var payload = formData
        payload["assessment"] = q.ASSESSMENT
        payload["bjid"] = q.BJID
        payload["bjmc"] = q.BJMC
        payload["data_jxb_id"] = String(q.DATA_JXB_ID)
        payload["data_jxb_js_id"] = String(q.DATA_JXB_JS_ID)
        payload["jsbh"] = q.JSBH
        payload["jsxm"] = q.JSXM
        payload["jxb_sj_ok"] = q.JXB_SJ_OK
        payload["kcbh"] = q.KCBH
        payload["kcmc"] = q.KCMC
        payload["kcywmc"] = q.KCYWMC
        payload["kkdw"] = q.KKDW
        payload["lang"] = q.LANG
        payload["skls_duty"] = q.SKLS_DUTY
        payload["termcode"] = q.TERMCODE
        payload["termname"] = q.TERMNAME

        let response = try await login.client.post("http://gste.xjtu.edu.cn/app/student/saveForm.do", form: payload)
        let object = try JSONSerialization.jsonObject(with: response.data)
        guard let dict = object as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        return (dict["ok"] as? Bool) ?? false
    }

    private func extractFormJSON(from html: String) -> Data? {
        guard let anchorRange = html.range(of: "pjzbApp.form") else {
            return nil
        }

        guard let equal = html[anchorRange.lowerBound...].firstIndex(of: "="),
              let braceStart = html[equal...].firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var inString = false
        var escaped = false
        var end: String.Index?

        var cursor = braceStart
        while cursor < html.endIndex {
            let char = html[cursor]
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
            } else {
                if char == "\"" {
                    inString = true
                } else if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        end = html.index(after: cursor)
                        break
                    }
                }
            }
            cursor = html.index(after: cursor)
        }

        guard let end else { return nil }
        var json = String(html[braceStart..<end])
        json = json.replacingOccurrences(of: ":\\s*webix\\.rules\\.isNotEmpty", with: ": \"isNotEmpty\"", options: .regularExpression)
        json = json.replacingOccurrences(of: ",\\s*([}\\]])", with: "$1", options: .regularExpression)
        return json.data(using: .utf8)
    }

    private func walkFormTree(_ object: [String: Any]) -> (meta: [String: String], questions: [FormQuestion]) {
        var meta: [String: String] = [:]
        var questions: [FormQuestion] = []

        func walk(node: Any?) {
            guard let node else { return }

            if let dict = node as? [String: Any] {
                let view = dict["view"] as? String ?? ""
                let hidden = (dict["hidden"] as? Bool) ?? false

                if hidden, ["hidden", "text"].contains(view) {
                    let key = (dict["id"] as? String) ?? (dict["name"] as? String) ?? ""
                    if !key.isEmpty {
                        meta[key] = dict["value"] as? String ?? ""
                    }
                }

                if !hidden, ["radio", "textarea", "text", "select"].contains(view) {
                    let id = (dict["id"] as? String) ?? (dict["name"] as? String) ?? ""
                    let name = (dict["label"] as? String) ?? (dict["value"] as? String) ?? ""

                    if !id.isEmpty, !name.isEmpty {
                        let options = (dict["options"] as? [[String: Any]] ?? []).map {
                            FormOption(id: $0.string("id"), value: $0.string("value"))
                        }
                        questions.append(FormQuestion(id: id, name: name, view: view, options: options))
                    }
                }

                for key in ["elements", "rows", "cols"] {
                    if let children = dict[key] as? [Any] {
                        for child in children {
                            walk(node: child)
                        }
                    }
                }
            }

            if let array = node as? [Any] {
                for child in array {
                    walk(node: child)
                }
            }
        }

        walk(node: object)
        return (meta, questions)
    }
}
