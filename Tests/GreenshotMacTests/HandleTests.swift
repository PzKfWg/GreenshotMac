import XCTest
import AppKit
@testable import GreenshotMac

final class HandleTests: XCTestCase {

    let testRect = CGRect(x: 10, y: 20, width: 100, height: 50)

    func testHandlePointsAtCorrectPositions() {
        XCTAssertEqual(HandlePosition.topLeft.point(in: testRect), CGPoint(x: 10, y: 20))
        XCTAssertEqual(HandlePosition.topRight.point(in: testRect), CGPoint(x: 110, y: 20))
        XCTAssertEqual(HandlePosition.bottomLeft.point(in: testRect), CGPoint(x: 10, y: 70))
        XCTAssertEqual(HandlePosition.bottomRight.point(in: testRect), CGPoint(x: 110, y: 70))
        XCTAssertEqual(HandlePosition.topCenter.point(in: testRect), CGPoint(x: 60, y: 20))
        XCTAssertEqual(HandlePosition.bottomCenter.point(in: testRect), CGPoint(x: 60, y: 70))
        XCTAssertEqual(HandlePosition.middleLeft.point(in: testRect), CGPoint(x: 10, y: 45))
        XCTAssertEqual(HandlePosition.middleRight.point(in: testRect), CGPoint(x: 110, y: 45))
    }

    func testResizeBottomRight() {
        let result = HandlePosition.bottomRight.resize(bounds: testRect, to: CGPoint(x: 150, y: 100))
        XCTAssertEqual(result.origin.x, 10)
        XCTAssertEqual(result.origin.y, 20)
        XCTAssertEqual(result.size.width, 140)
        XCTAssertEqual(result.size.height, 80)
    }

    func testResizeTopLeft() {
        let result = HandlePosition.topLeft.resize(bounds: testRect, to: CGPoint(x: 0, y: 10))
        XCTAssertEqual(result.origin.x, 0)
        XCTAssertEqual(result.origin.y, 10)
        XCTAssertEqual(result.size.width, 110)
        XCTAssertEqual(result.size.height, 60)
    }

    func testResizeStandardizesNegativeDimensions() {
        let result = HandlePosition.bottomRight.resize(bounds: testRect, to: CGPoint(x: 5, y: 10))
        XCTAssertGreaterThanOrEqual(result.width, 0)
        XCTAssertGreaterThanOrEqual(result.height, 0)
    }

    func testAllHandlePositionsCovered() {
        XCTAssertEqual(HandlePosition.allCases.count, 8)
    }
}
