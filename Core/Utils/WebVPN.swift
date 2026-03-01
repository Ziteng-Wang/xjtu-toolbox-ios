import Foundation
import CommonCrypto

enum WebVPN {
    static let institution = "webvpn.xjtu.edu.cn"
    static let loginURL = URL(string: AppConstants.URLS.webVPNLoginURL)!

    private static let key = Array("wrdvpnisthebest!".utf8)
    private static let iv = Array("wrdvpnisthebest!".utf8)

    private static var ivHex: String {
        iv.map { String(format: "%02x", $0) }.joined()
    }

    static func isWebVPNURL(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return host == institution
    }

    static func vpnURL(for originalURL: URL) -> URL {
        guard !isWebVPNURL(originalURL),
              let scheme = originalURL.scheme,
              let host = originalURL.host else {
            return originalURL
        }

        let encryptedHost = encryptHostname(host)
        let portSegment: String
        if let port = originalURL.port {
            portSegment = "-\(port)"
        } else {
            portSegment = ""
        }

        let path = originalURL.path.isEmpty ? "/" : originalURL.path
        let query = originalURL.query.map { "?\($0)" } ?? ""
        let urlString = "https://\(institution)/\(scheme)\(portSegment)/\(ivHex)\(encryptedHost)\(path)\(query)"
        return URL(string: urlString) ?? originalURL
    }

    static func originalURL(from vpnURL: URL) -> URL? {
        guard isWebVPNURL(vpnURL) else { return nil }

        let parts = vpnURL.path.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        let protocolPart = String(parts[0])
        let encodedPart = String(parts[1])
        let suffixPath = parts.dropFirst(2).joined(separator: "/")

        let scheme: String
        let port: Int?
        if let dashIndex = protocolPart.firstIndex(of: "-") {
            scheme = String(protocolPart[..<dashIndex])
            port = Int(protocolPart[protocolPart.index(after: dashIndex)...])
        } else {
            scheme = protocolPart
            port = nil
        }

        guard encodedPart.count > 32 else { return nil }
        let encryptedHex = String(encodedPart.dropFirst(32))
        guard let host = decryptHostname(encryptedHex) else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        components.path = "/" + suffixPath
        return components.url
    }

    private static func encryptHostname(_ hostname: String) -> String {
        let encrypted = cfb128Encrypt(Array(hostname.utf8), decrypt: false)
        return encrypted.map { String(format: "%02x", $0) }.joined()
    }

    private static func decryptHostname(_ hex: String) -> String? {
        guard let bytes = Data(hex: hex) else { return nil }
        let decrypted = cfb128Encrypt([UInt8](bytes), decrypt: true)
        return String(bytes: decrypted, encoding: .utf8)
    }

    // Algorithm aligned with Android/Python implementation: AES-ECB + manual CFB128 feedback.
    private static func cfb128Encrypt(_ input: [UInt8], decrypt: Bool) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: input.count)
        var feedback = iv
        var offset = 0

        while offset < input.count {
            guard let encryptedFeedback = aesECBEncrypt(block: feedback) else {
                return input
            }
            let blockLength = min(16, input.count - offset)

            for i in 0..<blockLength {
                output[offset + i] = input[offset + i] ^ encryptedFeedback[i]
            }

            if offset + 16 <= input.count {
                if decrypt {
                    feedback = Array(input[offset..<(offset + 16)])
                } else {
                    feedback = Array(output[offset..<(offset + 16)])
                }
            }
            offset += 16
        }

        return output
    }

    private static func aesECBEncrypt(block: [UInt8]) -> [UInt8]? {
        guard block.count == 16 else { return nil }

        var out = [UInt8](repeating: 0, count: 16)
        var outLen: size_t = 0
        let status = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionECBMode),
            key,
            key.count,
            nil,
            block,
            block.count,
            &out,
            out.count,
            &outLen
        )

        guard status == kCCSuccess else { return nil }
        return Array(out.prefix(outLen))
    }
}

private extension Data {
    init?(hex: String) {
        let count = hex.count / 2
        var data = Data(capacity: count)
        var index = hex.startIndex
        for _ in 0..<count {
            let next = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<next]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
