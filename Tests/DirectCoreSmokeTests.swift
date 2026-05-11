import Foundation
import GameTranslatorCore

struct TestFailure: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

@main
enum DirectCoreSmokeTests {
    static func main() throws {
        try testLanguageCodeMapper()
        try testTextNormalizer()
        try testFrameChangeDetector()
        try testTranslationCache()
        print("Direct core smoke tests passed.")
    }

    private static func testLanguageCodeMapper() throws {
        try expectEqual(LanguageCodeMapper.tencentTranslateCode(for: "简体中文"), "zh")
        try expectEqual(LanguageCodeMapper.tencentTranslateCode(for: "繁体中文"), "zh-TW")
        try expectEqual(LanguageCodeMapper.tencentTranslateCode(for: "en"), "en")
        try expectEqual(LanguageCodeMapper.tencentTranslateCode(for: "zh_CN"), "zh")
        try expectEqual(LanguageCodeMapper.tencentTranslateCode(for: "Japanese"), "ja")
        try expectEqual(LanguageCodeMapper.tencentTranslateCode(for: "Korean"), "ko")
        try expectEqual(LanguageCodeMapper.tencentTranslateCode(for: "English"), "en")
    }

    private static func testTextNormalizer() throws {
        let raw = "  こんにちは　世界  \nこんにちは 世界\n\n  次の行  "
        try expectEqual(TextNormalizer.normalizeGameText(raw), "こんにちは 世界\n次の行")
    }

    private static func testFrameChangeDetector() throws {
        var detector = FrameChangeDetector()
        try expect(detector.shouldProcess(fingerprint: 1), "first fingerprint should process")
        try expect(!detector.shouldProcess(fingerprint: 1), "same fingerprint should not process twice")
        try expect(detector.shouldProcess(fingerprint: 2), "changed fingerprint should process")
        detector.reset()
        try expect(detector.shouldProcess(fingerprint: 2), "reset should allow processing again")
    }

    private static func testTranslationCache() throws {
        let cache = TranslationCache()
        let zh = TranslationCacheKey(originalText: "こんにちは", targetLanguage: "简体中文", providerID: "tencent")
        let en = TranslationCacheKey(originalText: "こんにちは", targetLanguage: "English", providerID: "tencent")
        let otherProvider = TranslationCacheKey(originalText: "こんにちは", targetLanguage: "简体中文", providerID: "other")

        cache.insert("你好", for: zh)
        try expectEqual(cache.value(for: zh), "你好")
        try expectNil(cache.value(for: en), "cache should separate target languages")
        try expectNil(cache.value(for: otherProvider), "cache should separate providers")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw TestFailure(message: message)
        }
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T) throws {
        if actual != expected {
            throw TestFailure(message: "expected \(expected), got \(actual)")
        }
    }

    private static func expectEqual<T: Equatable>(_ actual: T?, _ expected: T) throws {
        if actual != expected {
            throw TestFailure(message: "expected \(expected), got \(String(describing: actual))")
        }
    }

    private static func expectNil<T>(_ actual: T?, _ message: String) throws {
        if actual != nil {
            throw TestFailure(message: "\(message); got \(String(describing: actual))")
        }
    }
}
