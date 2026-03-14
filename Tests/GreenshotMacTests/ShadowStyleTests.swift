import XCTest
import AppKit
@testable import GreenshotMac

final class ShadowStyleTests: XCTestCase {

    func testDefaultShadowHasExpectedValues() {
        let shadow = ShadowStyle.default
        XCTAssertTrue(shadow.enabled)
        XCTAssertEqual(shadow.blurRadius, 4)
        XCTAssertEqual(shadow.offset.width, 2)
        XCTAssertEqual(shadow.offset.height, -2)
    }

    func testNoneShadowIsDisabled() {
        let shadow = ShadowStyle.none
        XCTAssertFalse(shadow.enabled)
        XCTAssertEqual(shadow.blurRadius, 0)
    }

    func testShadowEquality() {
        let a = ShadowStyle.default
        let b = ShadowStyle.default
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, ShadowStyle.none)
    }
}
