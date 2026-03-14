import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class HandleResizeTests: XCTestCase {

    let originalBounds = CGRect(x: 100, y: 100, width: 200, height: 150)

    // MARK: - All 8 handle positions

    func testResizeTopLeft() {
        let result = HandlePosition.topLeft.resize(bounds: originalBounds, to: CGPoint(x: 80, y: 70))
        XCTAssertEqual(result.origin.x, 80, accuracy: 0.01)
        XCTAssertEqual(result.origin.y, 70, accuracy: 0.01)
        XCTAssertEqual(result.width, 220, accuracy: 0.01)  // 300 - 80
        XCTAssertEqual(result.height, 180, accuracy: 0.01) // 250 - 70
    }

    func testResizeTopCenter() {
        let result = HandlePosition.topCenter.resize(bounds: originalBounds, to: CGPoint(x: 200, y: 70))
        // TopCenter only changes Y origin and height
        XCTAssertEqual(result.origin.x, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.origin.y, 70, accuracy: 0.01)
        XCTAssertEqual(result.width, 200, accuracy: 0.01)   // unchanged
        XCTAssertEqual(result.height, 180, accuracy: 0.01)  // 250 - 70
    }

    func testResizeTopRight() {
        let result = HandlePosition.topRight.resize(bounds: originalBounds, to: CGPoint(x: 350, y: 70))
        XCTAssertEqual(result.origin.x, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.origin.y, 70, accuracy: 0.01)
        XCTAssertEqual(result.width, 250, accuracy: 0.01)   // 350 - 100
        XCTAssertEqual(result.height, 180, accuracy: 0.01)  // 250 - 70
    }

    func testResizeMiddleLeft() {
        let result = HandlePosition.middleLeft.resize(bounds: originalBounds, to: CGPoint(x: 80, y: 175))
        // MiddleLeft only changes X origin and width
        XCTAssertEqual(result.origin.x, 80, accuracy: 0.01)
        XCTAssertEqual(result.origin.y, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.width, 220, accuracy: 0.01)    // 300 - 80
        XCTAssertEqual(result.height, 150, accuracy: 0.01)   // unchanged
    }

    func testResizeMiddleRight() {
        let result = HandlePosition.middleRight.resize(bounds: originalBounds, to: CGPoint(x: 350, y: 175))
        // MiddleRight only changes width
        XCTAssertEqual(result.origin.x, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.origin.y, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.width, 250, accuracy: 0.01)    // 350 - 100
        XCTAssertEqual(result.height, 150, accuracy: 0.01)   // unchanged
    }

    func testResizeBottomLeft() {
        let result = HandlePosition.bottomLeft.resize(bounds: originalBounds, to: CGPoint(x: 80, y: 300))
        XCTAssertEqual(result.origin.x, 80, accuracy: 0.01)
        XCTAssertEqual(result.origin.y, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.width, 220, accuracy: 0.01)    // 300 - 80
        XCTAssertEqual(result.height, 200, accuracy: 0.01)   // 300 - 100
    }

    func testResizeBottomCenter() {
        let result = HandlePosition.bottomCenter.resize(bounds: originalBounds, to: CGPoint(x: 200, y: 300))
        // BottomCenter only changes height
        XCTAssertEqual(result.origin.x, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.origin.y, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.width, 200, accuracy: 0.01)    // unchanged
        XCTAssertEqual(result.height, 200, accuracy: 0.01)   // 300 - 100
    }

    func testResizeBottomRight() {
        let result = HandlePosition.bottomRight.resize(bounds: originalBounds, to: CGPoint(x: 350, y: 300))
        XCTAssertEqual(result.origin.x, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.origin.y, 100, accuracy: 0.01) // unchanged
        XCTAssertEqual(result.width, 250, accuracy: 0.01)    // 350 - 100
        XCTAssertEqual(result.height, 200, accuracy: 0.01)   // 300 - 100
    }

    // MARK: - Negative dimensions standardized

    func testResizeTopLeftBeyondOppositeCornerStandardizes() {
        // Drag top-left past bottom-right → negative dimensions get standardized
        let result = HandlePosition.topLeft.resize(bounds: originalBounds, to: CGPoint(x: 350, y: 300))
        XCTAssertGreaterThanOrEqual(result.width, 0)
        XCTAssertGreaterThanOrEqual(result.height, 0)
    }

    func testResizeBottomRightBeyondOppositeCornerStandardizes() {
        let result = HandlePosition.bottomRight.resize(bounds: originalBounds, to: CGPoint(x: 50, y: 50))
        XCTAssertGreaterThanOrEqual(result.width, 0)
        XCTAssertGreaterThanOrEqual(result.height, 0)
    }

    func testResizeMiddleLeftBeyondRightEdgeStandardizes() {
        let result = HandlePosition.middleLeft.resize(bounds: originalBounds, to: CGPoint(x: 400, y: 175))
        XCTAssertGreaterThanOrEqual(result.width, 0)
    }

    func testResizeMiddleRightBeyondLeftEdgeStandardizes() {
        let result = HandlePosition.middleRight.resize(bounds: originalBounds, to: CGPoint(x: 50, y: 175))
        XCTAssertGreaterThanOrEqual(result.width, 0)
    }

    // MARK: - Handle points

    func testHandlePointPositions() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 150)

        XCTAssertEqual(HandlePosition.topLeft.point(in: rect), CGPoint(x: 100, y: 100))
        XCTAssertEqual(HandlePosition.topCenter.point(in: rect), CGPoint(x: 200, y: 100))
        XCTAssertEqual(HandlePosition.topRight.point(in: rect), CGPoint(x: 300, y: 100))
        XCTAssertEqual(HandlePosition.middleLeft.point(in: rect), CGPoint(x: 100, y: 175))
        XCTAssertEqual(HandlePosition.middleRight.point(in: rect), CGPoint(x: 300, y: 175))
        XCTAssertEqual(HandlePosition.bottomLeft.point(in: rect), CGPoint(x: 100, y: 250))
        XCTAssertEqual(HandlePosition.bottomCenter.point(in: rect), CGPoint(x: 200, y: 250))
        XCTAssertEqual(HandlePosition.bottomRight.point(in: rect), CGPoint(x: 300, y: 250))
    }

    // MARK: - MiddleLeft/Right only affect width

    func testMiddleLeftOnlyAffectsWidth() {
        let result = HandlePosition.middleLeft.resize(bounds: originalBounds, to: CGPoint(x: 80, y: 999))
        XCTAssertEqual(result.height, originalBounds.height, accuracy: 0.01)
    }

    func testMiddleRightOnlyAffectsWidth() {
        let result = HandlePosition.middleRight.resize(bounds: originalBounds, to: CGPoint(x: 400, y: 999))
        XCTAssertEqual(result.height, originalBounds.height, accuracy: 0.01)
    }

    // MARK: - TopCenter/BottomCenter only affect height

    func testTopCenterOnlyAffectsHeight() {
        let result = HandlePosition.topCenter.resize(bounds: originalBounds, to: CGPoint(x: 999, y: 50))
        XCTAssertEqual(result.width, originalBounds.width, accuracy: 0.01)
    }

    func testBottomCenterOnlyAffectsHeight() {
        let result = HandlePosition.bottomCenter.resize(bounds: originalBounds, to: CGPoint(x: 999, y: 300))
        XCTAssertEqual(result.width, originalBounds.width, accuracy: 0.01)
    }

    // MARK: - Handle count

    func testAllHandlePositionsCovered() {
        XCTAssertEqual(HandlePosition.allCases.count, 8)
    }

    // MARK: - Cursor types

    func testCursorTypes() {
        XCTAssertEqual(HandlePosition.topLeft.cursor, .crosshair)
        XCTAssertEqual(HandlePosition.bottomRight.cursor, .crosshair)
        XCTAssertEqual(HandlePosition.topRight.cursor, .crosshair)
        XCTAssertEqual(HandlePosition.bottomLeft.cursor, .crosshair)
        XCTAssertEqual(HandlePosition.topCenter.cursor, .resizeUpDown)
        XCTAssertEqual(HandlePosition.bottomCenter.cursor, .resizeUpDown)
        XCTAssertEqual(HandlePosition.middleLeft.cursor, .resizeLeftRight)
        XCTAssertEqual(HandlePosition.middleRight.cursor, .resizeLeftRight)
    }
}
