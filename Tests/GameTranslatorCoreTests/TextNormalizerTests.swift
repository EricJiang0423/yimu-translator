import XCTest
@testable import GameTranslatorCore

final class TextNormalizerTests: XCTestCase {
    func testNormalizeTrimsWhitespaceAndDropsDuplicateLines() {
        let raw = "  こんにちは　世界  \nこんにちは 世界\n\n  次の行  "

        XCTAssertEqual(
            TextNormalizer.normalizeGameText(raw),
            "こんにちは 世界\n次の行"
        )
    }
}
