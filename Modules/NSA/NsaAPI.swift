import Foundation

struct NsaDetailItem: Identifiable, Hashable, Codable {
    var id: String { label }
    let label: String
    let value: String
}

struct NsaStudentProfile: Hashable, Codable {
    let name: String
    let studentId: String
    let college: String
    let major: String
    var details: [NsaDetailItem]
}

final class NsaAPI {
    private let login: JwxtLogin
    private let baseURL = "https://nsa.xjtu.edu.cn/zftal-xgxt-web"

    private let userInfoFields: [(code: String, label: String)] = [
        ("xbdm", "性别"),
        ("csrq", "出生日期"),
        ("mzdm", "民族"),
        ("zzmmdm", "政治面貌"),
        ("xxdm", "血型"),
        ("jgdm", "籍贯"),
        ("sg", "身高"),
        ("tz", "体重")
    ]

    private let schoolFields: [(code: String, label: String)] = [
        ("nj", "年级"),
        ("pycc", "培养层次"),
        ("sydm", "书院"),
        ("xqdm", "校区"),
        ("rxrq", "入学时间"),
        ("xz", "学制"),
        ("qsh", "宿舍号"),
        ("xjztdm", "学籍状态")
    ]

    init(login: JwxtLogin) {
        self.login = login
    }

    func getProfile() async throws -> NsaStudentProfile {
        let session = try await ensureSession()
        var basic = try await getBasicProfile(session: session)
        basic.details = try await getPersonalDetails()
        return basic
    }

    func getPersonalDetails() async throws -> [NsaDetailItem] {
        _ = try await ensureSession()

        var result: [NsaDetailItem] = []

        do {
            let response = try await login.client.get("\(baseURL)/dynamic/form/group/userInfo/default.zf?dataId=null")
            if let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
               object.int("code") == 0 {
                let fields = extractFields(from: object)
                for item in userInfoFields {
                    guard let field = fields[item.code] else { continue }
                    var value = resolveFieldValue(field)
                    if value.isEmpty { continue }
                    if item.code == "sg" { value = "\(value) cm" }
                    if item.code == "tz" { value = "\(value) kg" }
                    result.append(NsaDetailItem(label: item.label, value: value))
                }
            }
        } catch {
            // Non-fatal: keep best-effort details.
        }

        do {
            let response = try await login.client.get("\(baseURL)/dynamic/form/group/zxxx/default.zf?dataId=null")
            if let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
               object.int("code") == 0 {
                let fields = extractFields(from: object)
                for item in schoolFields {
                    guard let field = fields[item.code] else { continue }
                    var value = resolveFieldValue(field)
                    if value.isEmpty { continue }
                    if item.code == "nj" { value = "\(value)级" }
                    if item.code == "xz" { value = "\(value)年" }
                    result.append(NsaDetailItem(label: item.label, value: value))
                }
            }
        } catch {
            // Non-fatal: keep best-effort details.
        }

        return result
    }

    func getStudentPhoto(studentID: String) async throws -> Data? {
        _ = try await ensureSession()
        let url = "\(baseURL)/xsxx/xsxx/xsgl/getXszp.zf?yhm=\(studentID)"
        let response = try await login.client.get(url)

        guard response.http.statusCode == 200, !response.data.isEmpty else {
            return nil
        }

        let contentType = response.http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if contentType.contains("image") || contentType.contains("octet-stream") {
            return response.data.count >= 100 ? response.data : nil
        }

        guard let text = String(data: response.data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }

        if text.hasPrefix("data:image"),
           let raw = text.split(separator: ",", maxSplits: 1).last,
           let data = Data(base64Encoded: String(raw)) {
            return data
        }

        if text.hasPrefix("/9j/") || text.hasPrefix("iVBOR") {
            return Data(base64Encoded: text)
        }

        return nil
    }

    private func getBasicProfile(session: NsaSession) async throws -> NsaStudentProfile {
        let response = try await login.client.get("\(baseURL)/teacher/xtgl/index/getGrkpInfo.zf")
        guard let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        guard object.int("code") == 0 else {
            throw HTTPError.authenticationRequired
        }

        let data = object["data"] as? [String: Any] ?? [:]
        let name = data.string("xm", default: session.name)
        let studentID = data.string("zgh", default: session.studentID)
        let college = data.string("bmmc")
        let major = data.string("zymc")

        return NsaStudentProfile(
            name: name,
            studentId: studentID,
            college: college,
            major: major,
            details: []
        )
    }

    private func ensureSession() async throws -> NsaSession {
        if let session = try await checkSession() {
            if let roleCode = session.defaultRoleCode {
                await switchRole(roleCode)
            }
            return session
        }

        guard let oauthURL = try await getOAuthURL(), !oauthURL.isEmpty else {
            throw HTTPError.authenticationRequired
        }

        _ = try await login.client.get(oauthURL)

        guard let session = try await checkSession() else {
            throw HTTPError.authenticationRequired
        }

        if let roleCode = session.defaultRoleCode {
            await switchRole(roleCode)
        }

        return session
    }

    private func getOAuthURL() async throws -> String? {
        let response = try await login.client.get("\(baseURL)/teacher/xtgl/index/pd.zf")
        guard let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            throw HTTPError.invalidResponse
        }

        let data = object["data"] as? [String: Any] ?? [:]
        let rawURL = data.string("rzdldz")
        guard !rawURL.isEmpty else { return nil }

        if rawURL.hasPrefix("http://") {
            return "https://" + String(rawURL.dropFirst(7))
        }
        return rawURL
    }

    private func checkSession() async throws -> NsaSession? {
        let response = try await login.client.get("\(baseURL)/teacher/xtgl/index/getUserRoleInfo.zf")
        guard let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            throw HTTPError.invalidResponse
        }

        guard object.int("code", default: -1) == 0 else {
            return nil
        }

        let data = object["data"] as? [String: Any] ?? [:]
        let studentID = data.string("zgh")
        let name = data.string("xm").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !studentID.isEmpty || !name.isEmpty else {
            return nil
        }

        return NsaSession(
            studentID: studentID,
            name: name,
            defaultRoleCode: data["mrjsdm"] as? String
        )
    }

    private func switchRole(_ roleCode: String) async {
        do {
            _ = try await login.client.post(
                "\(baseURL)/teacher/xtgl/login/switchRole.zf",
                form: ["jsdm": roleCode]
            )
        } catch {
            // Non-fatal.
        }
    }

    private func extractFields(from root: [String: Any]) -> [String: [String: Any]] {
        let data = root["data"] as? [String: Any] ?? [:]
        let groups = data["groupFields"] as? [[String: Any]] ?? []
        var map: [String: [String: Any]] = [:]

        for group in groups {
            let fields = group["fields"] as? [[String: Any]] ?? []
            for field in fields {
                let code = field.string("fieldCode")
                if !code.isEmpty {
                    map[code] = field
                }
            }
        }

        return map
    }

    private func resolveFieldValue(_ field: [String: Any]) -> String {
        let raw = field.string("defaultValue").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return ""
        }

        let options = field["options"] as? [[String: Any]] ?? []
        for option in options where option.string("value") == raw {
            let label = option.string("label")
            if !label.isEmpty {
                return label
            }
        }

        return raw
    }
}

private struct NsaSession {
    let studentID: String
    let name: String
    let defaultRoleCode: String?
}
