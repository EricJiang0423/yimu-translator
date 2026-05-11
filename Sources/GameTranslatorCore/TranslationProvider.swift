import CryptoKit
import Foundation

public struct TranslationRequest: Equatable, Sendable {
    public let text: String
    public let sourceLanguage: String
    public let targetLanguage: String

    public init(text: String, sourceLanguage: String, targetLanguage: String) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public protocol TranslationProvider: Sendable {
    var id: String { get }
    func translate(_ request: TranslationRequest) async throws -> String
}

public enum TranslationProviderError: LocalizedError, Equatable, Sendable {
    case missingCredentialID
    case missingAPISecret
    case invalidSourceLanguage(String)
    case invalidTargetLanguage(String)
    case httpStatus(Int, String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .missingCredentialID:
            return "Missing Tencent SecretId."
        case .missingAPISecret:
            return "Missing Tencent SecretKey."
        case .invalidSourceLanguage(let value):
            return "Invalid source language: \(value)"
        case .invalidTargetLanguage(let value):
            return "Invalid target language: \(value)"
        case .httpStatus(let status, let body):
            return "HTTP \(status): \(body)"
        case .emptyResponse:
            return "Tencent TMT returned an empty response."
        }
    }
}

public struct PairCredential: Equatable, Sendable {
    public let id: String
    public let secret: String

    public init(id: String, secret: String) throws {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else {
            throw TranslationProviderError.missingCredentialID
        }
        guard !trimmedSecret.isEmpty else {
            throw TranslationProviderError.missingAPISecret
        }
        self.id = trimmedID
        self.secret = trimmedSecret
    }
}

public final class TencentTMTTranslationProvider: TranslationProvider, @unchecked Sendable {
    public let id: String
    private let credential: PairCredential
    private let region: String
    private let session: URLSession
    private let host = "tmt.tencentcloudapi.com"
    private let service = "tmt"
    private let action = "TextTranslate"
    private let version = "2018-03-21"

    public init(secretID: String, secretKey: String, region: String = "ap-guangzhou", session: URLSession = .shared) throws {
        self.credential = try PairCredential(id: secretID, secret: secretKey)
        self.region = region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ap-guangzhou" : region
        self.session = session
        self.id = "tencent-tmt:\(self.region)"
    }

    public func translate(_ request: TranslationRequest) async throws -> String {
        guard let sourceCode = LanguageCodeMapper.tencentTranslateCode(for: request.sourceLanguage) else {
            throw TranslationProviderError.invalidSourceLanguage(request.sourceLanguage)
        }
        guard let targetCode = LanguageCodeMapper.tencentTranslateCode(for: request.targetLanguage) else {
            throw TranslationProviderError.invalidTargetLanguage(request.targetLanguage)
        }

        let payload = TencentTranslateRequest(
            SourceText: request.text,
            Source: sourceCode,
            Target: targetCode,
            ProjectId: 0
        )
        let payloadData = try JSONEncoder().encode(payload)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"
        let timestamp = Int(Date().timeIntervalSince1970)
        let date = DateFormatting.utcDateString(fromUnixTimestamp: timestamp)
        let contentType = "application/json; charset=utf-8"
        let signedHeaders = "content-type;host;x-tc-action"
        let canonicalHeaders = "content-type:\(contentType)\nhost:\(host)\nx-tc-action:\(action.lowercased())\n"
        let canonicalRequest = [
            "POST",
            "/",
            "",
            canonicalHeaders,
            signedHeaders,
            payloadString.sha256Hex()
        ].joined(separator: "\n")
        let credentialScope = "\(date)/\(service)/tc3_request"
        let stringToSign = [
            "TC3-HMAC-SHA256",
            String(timestamp),
            credentialScope,
            canonicalRequest.sha256Hex()
        ].joined(separator: "\n")
        let secretDate = HMAC<SHA256>.authenticationCode(
            for: Data(date.utf8),
            using: SymmetricKey(data: Data("TC3\(credential.secret)".utf8))
        ).data
        let secretService = HMAC<SHA256>.authenticationCode(
            for: Data(service.utf8),
            using: SymmetricKey(data: secretDate)
        ).data
        let secretSigning = HMAC<SHA256>.authenticationCode(
            for: Data("tc3_request".utf8),
            using: SymmetricKey(data: secretService)
        ).data
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: SymmetricKey(data: secretSigning)
        ).data.hexString

        var urlRequest = URLRequest(url: URL(string: "https://\(host)/")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(host, forHTTPHeaderField: "Host")
        urlRequest.setValue(action, forHTTPHeaderField: "X-TC-Action")
        urlRequest.setValue(String(timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        urlRequest.setValue(version, forHTTPHeaderField: "X-TC-Version")
        urlRequest.setValue(region, forHTTPHeaderField: "X-TC-Region")
        urlRequest.setValue(
            "TC3-HMAC-SHA256 Credential=\(credential.id)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)",
            forHTTPHeaderField: "Authorization"
        )
        urlRequest.httpBody = payloadData
        urlRequest.timeoutInterval = 6

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.emptyResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TranslationProviderError.httpStatus(httpResponse.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(TencentTranslateResponse.self, from: data)
        if let error = decoded.Response.Error {
            throw TranslationProviderError.httpStatus(-1, "\(error.Code): \(error.Message)")
        }
        let translated = decoded.Response.TargetText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let translated, !translated.isEmpty else {
            throw TranslationProviderError.emptyResponse
        }
        return translated
    }
}

public enum LanguageCodeMapper {
    public static func tencentTranslateCode(for targetLanguage: String) -> String? {
        generalCode(for: targetLanguage, simplifiedChinese: "zh", traditionalChinese: "zh-TW")
    }

    private static func generalCode(
        for targetLanguage: String,
        simplifiedChinese: String,
        traditionalChinese: String,
        japanese: String = "ja",
        korean: String = "ko"
    ) -> String? {
        let normalized = targetLanguage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        switch normalized {
        case "简体中文", "中文", "中国语", "汉语", "zh", "zh-cn", "simplified chinese", "chinese":
            return simplifiedChinese
        case "繁体中文", "正體中文", "zh-tw", "traditional chinese":
            return traditionalChinese
        case "英文", "英语", "english":
            return "en"
        case "日文", "日语", "japanese":
            return japanese
        case "韩文", "韩语", "korean":
            return korean
        default:
            return canonicalISOCode(normalized)
        }
    }

    private static func canonicalISOCode(_ normalized: String) -> String? {
        guard normalized.range(of: #"^[a-z]{2,3}(-[a-z0-9]{2,8})?$"#, options: .regularExpression) != nil else {
            return nil
        }
        let parts = normalized.split(separator: "-", maxSplits: 1).map(String.init)
        if parts.count == 2, parts[1].count == 2 {
            return "\(parts[0])-\(parts[1].uppercased())"
        }
        return normalized
    }
}

private enum DateFormatting {
    static func utcDateString(fromUnixTimestamp timestamp: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}

private struct TencentTranslateRequest: Encodable {
    let SourceText: String
    let Source: String
    let Target: String
    let ProjectId: Int
}

private struct TencentTranslateResponse: Decodable {
    let Response: Payload

    struct Payload: Decodable {
        let TargetText: String?
        let Error: APIError?
    }

    struct APIError: Decodable {
        let Code: String
        let Message: String
    }
}

private extension String {
    func sha256Hex() -> String {
        SHA256.hash(data: Data(utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension MessageAuthenticationCode {
    var data: Data {
        Data(self)
    }
}
