import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var pollingInterval: TimeInterval
    public var credentialID: String
    public var apiSecret: String
    public var tencentRegion: String
    public var overlayOpacity: Double
    public var overlayFontSize: Double

    public init(
        sourceLanguage: String = "Japanese",
        targetLanguage: String = "简体中文",
        pollingInterval: TimeInterval = 0.45,
        credentialID: String = "",
        apiSecret: String = "",
        tencentRegion: String = "ap-guangzhou",
        overlayOpacity: Double = 0.72,
        overlayFontSize: Double = 20
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.pollingInterval = pollingInterval
        self.credentialID = credentialID
        self.apiSecret = apiSecret
        self.tencentRegion = tencentRegion
        self.overlayOpacity = overlayOpacity
        self.overlayFontSize = overlayFontSize
    }

    public static let defaults = AppConfiguration()

    public var clampedPollingInterval: TimeInterval {
        min(max(pollingInterval, 0.2), 3.0)
    }

    public var clampedOverlayOpacity: Double {
        min(max(overlayOpacity, 0.25), 1.0)
    }

    public var clampedOverlayFontSize: Double {
        min(max(overlayFontSize, 12), 36)
    }

    private enum CodingKeys: String, CodingKey {
        case sourceLanguage
        case targetLanguage
        case pollingInterval
        case credentialID
        case apiSecret
        case tencentRegion
        case model
        case overlayOpacity
        case overlayFontSize
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sourceLanguage = try values.decodeIfPresent(String.self, forKey: .sourceLanguage) ?? Self.defaults.sourceLanguage
        targetLanguage = try values.decodeIfPresent(String.self, forKey: .targetLanguage) ?? Self.defaults.targetLanguage
        pollingInterval = try values.decodeIfPresent(TimeInterval.self, forKey: .pollingInterval) ?? Self.defaults.pollingInterval
        credentialID = try values.decodeIfPresent(String.self, forKey: .credentialID) ?? Self.defaults.credentialID
        apiSecret = try values.decodeIfPresent(String.self, forKey: .apiSecret) ?? Self.defaults.apiSecret
        tencentRegion = try values.decodeIfPresent(String.self, forKey: .tencentRegion)
            ?? values.decodeIfPresent(String.self, forKey: .model)
            ?? Self.defaults.tencentRegion
        overlayOpacity = try values.decodeIfPresent(Double.self, forKey: .overlayOpacity) ?? Self.defaults.overlayOpacity
        overlayFontSize = try values.decodeIfPresent(Double.self, forKey: .overlayFontSize) ?? Self.defaults.overlayFontSize
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(sourceLanguage, forKey: .sourceLanguage)
        try values.encode(targetLanguage, forKey: .targetLanguage)
        try values.encode(pollingInterval, forKey: .pollingInterval)
        try values.encode(credentialID, forKey: .credentialID)
        try values.encode(apiSecret, forKey: .apiSecret)
        try values.encode(tencentRegion, forKey: .tencentRegion)
        try values.encode(overlayOpacity, forKey: .overlayOpacity)
        try values.encode(overlayFontSize, forKey: .overlayFontSize)
    }
}
