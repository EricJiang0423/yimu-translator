import XCTest
@testable import GameTranslatorCore

final class LanguageCodeMapperTests: XCTestCase {
    func testMapsCommonChineseNamesToTencentCodes() {
        XCTAssertEqual(LanguageCodeMapper.tencentTranslateCode(for: "简体中文"), "zh")
        XCTAssertEqual(LanguageCodeMapper.tencentTranslateCode(for: "繁体中文"), "zh-TW")
    }

    func testPassesThroughIsoStyleCodes() {
        XCTAssertEqual(LanguageCodeMapper.tencentTranslateCode(for: "en"), "en")
        XCTAssertEqual(LanguageCodeMapper.tencentTranslateCode(for: "zh_CN"), "zh")
    }

    func testMapsCommonGameSourceLanguages() {
        XCTAssertEqual(LanguageCodeMapper.tencentTranslateCode(for: "Japanese"), "ja")
        XCTAssertEqual(LanguageCodeMapper.tencentTranslateCode(for: "Korean"), "ko")
        XCTAssertEqual(LanguageCodeMapper.tencentTranslateCode(for: "English"), "en")
    }
}
