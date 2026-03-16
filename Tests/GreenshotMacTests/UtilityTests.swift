import XCTest
import AppKit
@testable import GreenshotMac

// MARK: - DiagonalDirection Tests

@MainActor
final class DiagonalDirectionTests: XCTestCase {

    func testFromTopLeftToBottomRight() {
        let dir = DiagonalDirection.from(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 100))
        XCTAssertEqual(dir, .topLeftToBottomRight)
    }

    func testFromBottomLeftToTopRight() {
        let dir = DiagonalDirection.from(start: CGPoint(x: 0, y: 100), end: CGPoint(x: 100, y: 0))
        XCTAssertEqual(dir, .bottomLeftToTopRight)
    }

    func testFromBottomRightToTopLeft() {
        let dir = DiagonalDirection.from(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 0, y: 0))
        XCTAssertEqual(dir, .bottomRightToTopLeft)
    }

    func testFromTopRightToBottomLeft() {
        let dir = DiagonalDirection.from(start: CGPoint(x: 100, y: 0), end: CGPoint(x: 0, y: 100))
        XCTAssertEqual(dir, .topRightToBottomLeft)
    }

    func testHorizontalRightIsTopLeftToBottomRight() {
        // When end.x >= start.x and end.y >= start.y (equal)
        let dir = DiagonalDirection.from(start: CGPoint(x: 0, y: 50), end: CGPoint(x: 100, y: 50))
        XCTAssertEqual(dir, .topLeftToBottomRight)
    }

    func testVerticalDownIsTopLeftToBottomRight() {
        let dir = DiagonalDirection.from(start: CGPoint(x: 50, y: 0), end: CGPoint(x: 50, y: 100))
        XCTAssertEqual(dir, .topLeftToBottomRight)
    }

    func testSamePointIsTopLeftToBottomRight() {
        let dir = DiagonalDirection.from(start: CGPoint(x: 50, y: 50), end: CGPoint(x: 50, y: 50))
        XCTAssertEqual(dir, .topLeftToBottomRight)
    }
}

// MARK: - distanceFromPointToLineSegment Tests

@MainActor
final class DistanceToLineSegmentTests: XCTestCase {

    func testPointOnLineSegment() {
        let dist = distanceFromPointToLineSegment(
            point: CGPoint(x: 50, y: 50),
            lineStart: CGPoint(x: 0, y: 0),
            lineEnd: CGPoint(x: 100, y: 100)
        )
        XCTAssertEqual(dist, 0, accuracy: 0.01)
    }

    func testPointPerpendicularToSegment() {
        // Line from (0,0) to (100,0), point at (50, 10)
        let dist = distanceFromPointToLineSegment(
            point: CGPoint(x: 50, y: 10),
            lineStart: CGPoint(x: 0, y: 0),
            lineEnd: CGPoint(x: 100, y: 0)
        )
        XCTAssertEqual(dist, 10, accuracy: 0.01)
    }

    func testPointBeyondStartOfSegment() {
        // Line from (10,0) to (100,0), point at (0, 0)
        let dist = distanceFromPointToLineSegment(
            point: CGPoint(x: 0, y: 0),
            lineStart: CGPoint(x: 10, y: 0),
            lineEnd: CGPoint(x: 100, y: 0)
        )
        XCTAssertEqual(dist, 10, accuracy: 0.01)
    }

    func testPointBeyondEndOfSegment() {
        // Line from (0,0) to (90,0), point at (100, 0)
        let dist = distanceFromPointToLineSegment(
            point: CGPoint(x: 100, y: 0),
            lineStart: CGPoint(x: 0, y: 0),
            lineEnd: CGPoint(x: 90, y: 0)
        )
        XCTAssertEqual(dist, 10, accuracy: 0.01)
    }

    func testZeroLengthLine() {
        // Line of zero length — should return distance to the single point
        let dist = distanceFromPointToLineSegment(
            point: CGPoint(x: 10, y: 0),
            lineStart: CGPoint(x: 0, y: 0),
            lineEnd: CGPoint(x: 0, y: 0)
        )
        XCTAssertEqual(dist, 10, accuracy: 0.01)
    }

    func testPointAtStartOfSegment() {
        let dist = distanceFromPointToLineSegment(
            point: CGPoint(x: 0, y: 0),
            lineStart: CGPoint(x: 0, y: 0),
            lineEnd: CGPoint(x: 100, y: 100)
        )
        XCTAssertEqual(dist, 0, accuracy: 0.01)
    }

    func testPointAtEndOfSegment() {
        let dist = distanceFromPointToLineSegment(
            point: CGPoint(x: 100, y: 100),
            lineStart: CGPoint(x: 0, y: 0),
            lineEnd: CGPoint(x: 100, y: 100)
        )
        XCTAssertEqual(dist, 0, accuracy: 0.01)
    }

    func testDiagonalLine() {
        // Line from (0,0) to (100,100), point at (0,100)
        // Distance from (0,100) to the line y=x is |0-100|/sqrt(2) ≈ 70.71
        // But since the segment is clamped, closest point is (100,100), distance = 100
        // Wait, closest projection is t = (0*100 + 100*100)/20000 = 0.5
        // Closest point is (50,50), distance = sqrt(50^2 + 50^2) ≈ 70.71
        let dist = distanceFromPointToLineSegment(
            point: CGPoint(x: 0, y: 100),
            lineStart: CGPoint(x: 0, y: 0),
            lineEnd: CGPoint(x: 100, y: 100)
        )
        XCTAssertEqual(dist, 70.71, accuracy: 0.1)
    }
}

// MARK: - AnnotationStyle Tests

@MainActor
final class AnnotationStyleTests: XCTestCase {

    func testDefaultValues() {
        let style = AnnotationStyle()
        XCTAssertEqual(style.strokeColor, .systemRed)
        XCTAssertEqual(style.fillColor, .clear)
        XCTAssertEqual(style.strokeWidth, 2.0)
        XCTAssertEqual(style.fontSize, 14.0)
        XCTAssertEqual(style.fontName, "Helvetica")
        XCTAssertTrue(style.shadow.enabled)
    }

    func testEquality() {
        let style1 = AnnotationStyle()
        let style2 = AnnotationStyle()
        XCTAssertEqual(style1, style2)
    }

    func testInequalityStrokeWidth() {
        var style1 = AnnotationStyle()
        var style2 = AnnotationStyle()
        style1.strokeWidth = 5.0
        style2.strokeWidth = 2.0
        XCTAssertNotEqual(style1, style2)
    }

    func testInequalityShadow() {
        var style1 = AnnotationStyle()
        var style2 = AnnotationStyle()
        style1.shadow = .default
        style2.shadow = .none
        XCTAssertNotEqual(style1, style2)
    }

    func testInequalityFontName() {
        var style1 = AnnotationStyle()
        var style2 = AnnotationStyle()
        style1.fontName = "Courier"
        style2.fontName = "Helvetica"
        XCTAssertNotEqual(style1, style2)
    }
}

// MARK: - AnnotationTool Tests

@MainActor
final class AnnotationToolTests: XCTestCase {

    func testAllToolsCovered() {
        let allTools = AnnotationTool.allCases
        XCTAssertEqual(allTools.count, 13) // select + 8 annotations (incl. freehand) + pixelate + highlight + obfuscate + crop
    }

    func testToolRawValues() {
        XCTAssertEqual(AnnotationTool.select.rawValue, "select")
        XCTAssertEqual(AnnotationTool.rectangle.rawValue, "rectangle")
        XCTAssertEqual(AnnotationTool.ellipse.rawValue, "ellipse")
        XCTAssertEqual(AnnotationTool.line.rawValue, "line")
        XCTAssertEqual(AnnotationTool.arrow.rawValue, "arrow")
        XCTAssertEqual(AnnotationTool.text.rawValue, "text")
        XCTAssertEqual(AnnotationTool.speechBubble.rawValue, "speechBubble")
        XCTAssertEqual(AnnotationTool.stepLabel.rawValue, "stepLabel")
        XCTAssertEqual(AnnotationTool.pixelate.rawValue, "pixelate")
        XCTAssertEqual(AnnotationTool.highlight.rawValue, "highlight")
        XCTAssertEqual(AnnotationTool.freehand.rawValue, "freehand")
        XCTAssertEqual(AnnotationTool.crop.rawValue, "crop")
    }
}

// MARK: - ShadowStyle Extended Tests

@MainActor
final class ShadowStyleExtendedTests: XCTestCase {

    func testDefaultValues() {
        let shadow = ShadowStyle.default
        XCTAssertTrue(shadow.enabled)
        XCTAssertEqual(shadow.offset, CGSize(width: 2, height: -2))
        XCTAssertEqual(shadow.blurRadius, 4)
    }

    func testNoneValues() {
        let shadow = ShadowStyle.none
        XCTAssertFalse(shadow.enabled)
        XCTAssertEqual(shadow.offset, .zero)
        XCTAssertEqual(shadow.blurRadius, 0)
    }

    func testDefaultNotEqualToNone() {
        XCTAssertNotEqual(ShadowStyle.default, ShadowStyle.none)
    }

    func testCustomShadow() {
        let shadow = ShadowStyle(
            enabled: true,
            offset: CGSize(width: 5, height: -5),
            blurRadius: 10,
            color: NSColor.blue.withAlphaComponent(0.3)
        )
        XCTAssertTrue(shadow.enabled)
        XCTAssertEqual(shadow.offset.width, 5)
        XCTAssertEqual(shadow.blurRadius, 10)
    }

    func testEqualCustomShadows() {
        let shadow1 = ShadowStyle(enabled: true, offset: CGSize(width: 3, height: -3), blurRadius: 6, color: .black)
        let shadow2 = ShadowStyle(enabled: true, offset: CGSize(width: 3, height: -3), blurRadius: 6, color: .black)
        XCTAssertEqual(shadow1, shadow2)
    }
}

// MARK: - Preferences Tests

@MainActor
final class PreferencesTests: XCTestCase {

    func testDefaultStrokeWidthPositive() {
        XCTAssertGreaterThan(Preferences.shared.defaultStrokeWidth, 0)
    }

    func testZeroStrokeWidthReturnsFallback() {
        let prefs = Preferences.shared
        let original = prefs.defaultStrokeWidth

        prefs.defaultStrokeWidth = 0
        XCTAssertEqual(prefs.defaultStrokeWidth, 2.0) // Falls back to default

        // Restore
        prefs.defaultStrokeWidth = original
    }

    func testNegativeStrokeWidthReturnsFallback() {
        let prefs = Preferences.shared
        let original = prefs.defaultStrokeWidth

        prefs.defaultStrokeWidth = -5
        XCTAssertEqual(prefs.defaultStrokeWidth, 2.0) // Falls back to default

        // Restore
        prefs.defaultStrokeWidth = original
    }

    func testScreenshotFolderHasDefault() {
        let folder = Preferences.shared.screenshotFolder
        XCTAssertFalse(folder.isEmpty)
    }
}
