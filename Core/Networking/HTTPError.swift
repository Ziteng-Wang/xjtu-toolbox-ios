import Foundation

enum HTTPError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case emptyBody
    case serverError(status: Int, message: String)
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效链接"
        case .invalidResponse:
            return "无效响应"
        case .emptyBody:
            return "响应为空"
        case let .serverError(status, message):
            return "服务器错误(\(status)): \(message)"
        case .authenticationRequired:
            return "需要重新登录"
        }
    }
}
