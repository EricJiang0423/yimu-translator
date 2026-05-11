import Foundation

public struct TranslationCacheKey: Hashable, Codable, Equatable, Sendable {
    public let originalText: String
    public let targetLanguage: String
    public let providerID: String

    public init(originalText: String, targetLanguage: String, providerID: String) {
        self.originalText = originalText
        self.targetLanguage = targetLanguage
        self.providerID = providerID
    }
}

public final class TranslationCache: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [TranslationCacheKey: String] = [:]

    public init() {}

    public func value(for key: TranslationCacheKey) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    public func insert(_ value: String, for key: TranslationCacheKey) {
        lock.lock()
        values[key] = value
        lock.unlock()
    }

    public func removeAll() {
        lock.lock()
        values.removeAll()
        lock.unlock()
    }
}
