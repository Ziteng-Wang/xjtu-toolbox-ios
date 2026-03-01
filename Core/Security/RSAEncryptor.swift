import Foundation
import Security

enum RSAEncryptor {
    static func encryptPassword(_ password: String, withPEM pem: String) throws -> String {
        let keyData = try pemToDER(pem)

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() as Error? ?? HTTPError.invalidResponse
        }

        let message = Data(password.utf8)
        guard let encrypted = SecKeyCreateEncryptedData(key, .rsaEncryptionPKCS1, message as CFData, &error) as Data? else {
            throw error?.takeRetainedValue() as Error? ?? HTTPError.invalidResponse
        }

        return "__RSA__\(encrypted.base64EncodedString())"
    }

    private static func pemToDER(_ pem: String) throws -> Data {
        let cleaned = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        guard let data = Data(base64Encoded: cleaned) else {
            throw HTTPError.invalidResponse
        }
        return data
    }
}
