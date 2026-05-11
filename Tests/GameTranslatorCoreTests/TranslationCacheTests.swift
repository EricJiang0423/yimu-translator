import XCTest
@testable import GameTranslatorCore

final class TranslationCacheTests: XCTestCase {
    func testCacheSeparatesTargetLanguageAndProvider() {
        let cache = TranslationCache()
        let zh = TranslationCacheKey(originalText: "こんにちは", targetLanguage: "简体中文", providerID: "mock")
        let en = TranslationCacheKey(originalText: "こんにちは", targetLanguage: "English", providerID: "mock")
        let otherProvider = TranslationCacheKey(originalText: "こんにちは", targetLanguage: "简体中文", providerID: "other")

        cache.insert("你好", for: zh)

        XCTAssertEqual(cache.value(for: zh), "你好")
        XCTAssertNil(cache.value(for: en))
        XCTAssertNil(cache.value(for: otherProvider))
    }
}
