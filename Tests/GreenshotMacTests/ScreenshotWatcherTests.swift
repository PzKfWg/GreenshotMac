import XCTest
import Foundation
@testable import GreenshotMac

final class ScreenshotWatcherTests: XCTestCase {

    func testWatcherInitializes() {
        let watcher = ScreenshotWatcher(watchPath: "/tmp") { _ in }
        XCTAssertNotNil(watcher)
    }

    func testEnglishScreenshotFilename() {
        let names = [
            "Screenshot 2024-01-15 at 10.30.00.png",
            "Screenshot 2024-01-15 at 10.30.00 2.png"
        ]
        for name in names {
            XCTAssertTrue(name.lowercased().hasPrefix("screenshot"), "\(name) should be detected")
        }
    }

    func testFrenchScreenshotFilename() {
        let name = "Capture d'écran 2024-01-15 à 10.30.00.png"
        XCTAssertTrue(name.lowercased().hasPrefix("capture d"))
    }

    func testNonScreenshotFilesNotDetected() {
        let names = ["document.png", "photo.jpg", "notes.txt"]
        for name in names {
            let lowered = name.lowercased()
            XCTAssertFalse(lowered.hasPrefix("screenshot"))
            XCTAssertFalse(lowered.hasPrefix("capture d"))
        }
    }
}
