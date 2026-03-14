import AppKit
import UniformTypeIdentifiers

@MainActor
enum FileExporter {
    enum ImageFormat: String, CaseIterable, Sendable {
        case png = "PNG"
        case jpeg = "JPEG"

        var utType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            }
        }

        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            }
        }

        nonisolated var bitmapType: NSBitmapImageRep.FileType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            }
        }
    }

    static func save(image: NSImage, suggestedName: String? = nil, from window: NSWindow?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = suggestedName ?? defaultFilename()
        panel.canCreateDirectories = true

        if let window = window {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url {
                    writeImage(image, to: url)
                }
            }
        } else {
            let response = panel.runModal()
            if response == .OK, let url = panel.url {
                writeImage(image, to: url)
            }
        }
    }

    static func quickSave(image: NSImage, to directory: String, format: ImageFormat = .png) -> URL? {
        let dir = (directory as NSString).expandingTildeInPath
        let filename = defaultFilename() + "." + format.fileExtension
        let url = URL(fileURLWithPath: dir).appendingPathComponent(filename)
        return writeImage(image, to: url) ? url : nil
    }

    @discardableResult
    nonisolated static func writeImage(_ image: NSImage, to url: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return false }

        let format: ImageFormat = url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
            ? .jpeg : .png

        let properties: [NSBitmapImageRep.PropertyKey: Any] = format == .jpeg
            ? [.compressionFactor: 0.9]
            : [:]

        guard let data = bitmap.representation(using: format.bitmapType, properties: properties) else { return false }

        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    private static func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Annotated \(formatter.string(from: Date()))"
    }
}
