import XCTest
@testable import GameTranslatorCore

final class FrameChangeDetectorTests: XCTestCase {
    func testOnlyProcessesChangedFingerprints() {
        var detector = FrameChangeDetector()

        XCTAssertTrue(detector.shouldProcess(fingerprint: 1))
        XCTAssertFalse(detector.shouldProcess(fingerprint: 1))
        XCTAssertTrue(detector.shouldProcess(fingerprint: 2))

        detector.reset()
        XCTAssertTrue(detector.shouldProcess(fingerprint: 2))
    }
}
