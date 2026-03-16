import XCTest
import AppKit
@testable import GreenshotMac

final class FileExporterTests: XCTestCase {

    private func createTestImage(width: Int = 100, height: Int = 100, color: NSColor = .red) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: width, height: height))
        image.unlockFocus()
        return image
    }

    func testWritePNGImage() throws {
        let image = createTestImage()
        let tmpDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: tmpDir).appendingPathComponent("test_export_\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let success = FileExporter.writeImage(image, to: url)
        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testWriteJPEGImage() throws {
        let image = createTestImage()
        let tmpDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: tmpDir).appendingPathComponent("test_export_\(UUID()).jpg")
        defer { try? FileManager.default.removeItem(at: url) }

        let success = FileExporter.writeImage(image, to: url)
        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testQuickSaveCreatesFile() throws {
        let image = createTestImage()
        let tmpDir = NSTemporaryDirectory()
        let url = FileExporter.quickSave(image: image, to: tmpDir, format: .png)
        XCTAssertNotNil(url)

        if let url = url {
            defer { try? FileManager.default.removeItem(at: url) }
            XCTAssertTrue(url.lastPathComponent.hasPrefix("Annoté"))
            XCTAssertEqual(url.pathExtension, "png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testImageFormatExtensions() {
        XCTAssertEqual(FileExporter.ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(FileExporter.ImageFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(FileExporter.ImageFormat.gif.fileExtension, "gif")
        XCTAssertEqual(FileExporter.ImageFormat.bmp.fileExtension, "bmp")
        XCTAssertEqual(FileExporter.ImageFormat.tiff.fileExtension, "tiff")
    }

    func testWriteBMPImage() throws {
        let image = createTestImage()
        let tmpDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: tmpDir).appendingPathComponent("test_export_\(UUID()).bmp")
        defer { try? FileManager.default.removeItem(at: url) }

        let success = FileExporter.writeImage(image, to: url)
        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testWriteTIFFImage() throws {
        let image = createTestImage()
        let tmpDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: tmpDir).appendingPathComponent("test_export_\(UUID()).tiff")
        defer { try? FileManager.default.removeItem(at: url) }

        let success = FileExporter.writeImage(image, to: url)
        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
