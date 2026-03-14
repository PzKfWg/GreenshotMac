import Foundation

final class ScreenshotWatcher: @unchecked Sendable {
    private let watchPath: String
    private let onNewScreenshot: (URL) -> Void
    private var stream: FSEventStreamRef?
    private var lastEventTime: Date = .distantPast
    private var knownFiles: Set<String> = []

    init(watchPath: String, onNewScreenshot: @escaping (URL) -> Void) {
        self.watchPath = (watchPath as NSString).expandingTildeInPath
        self.onNewScreenshot = onNewScreenshot
        snapshotExistingFiles()
    }

    deinit {
        stop()
    }

    func start() {
        guard stream == nil else { return }

        let pathsToWatch = [watchPath] as CFArray
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<ScreenshotWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

            for i in 0..<numEvents {
                watcher.handleEvent(path: paths[i])
            }
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func snapshotExistingFiles() {
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: watchPath) {
            knownFiles = Set(contents)
        }
    }

    private func handleEvent(path: String) {
        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent

        guard !knownFiles.contains(filename) else { return }
        guard isScreenshotFile(filename) else { return }
        guard isImageFile(url) else { return }

        // Debounce: ignore events within 0.5s of each other
        let now = Date()
        guard now.timeIntervalSince(lastEventTime) > 0.5 else { return }
        lastEventTime = now

        knownFiles.insert(filename)

        // Small delay to ensure file is fully written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onNewScreenshot(url)
        }
    }

    private func isScreenshotFile(_ filename: String) -> Bool {
        // macOS screenshot filenames: "Screenshot YYYY-MM-DD at HH.MM.SS.png" (English)
        // or localized variants like "Capture d'écran..." (French)
        let lowered = filename.lowercased()
        return lowered.hasPrefix("screenshot") ||
               lowered.hasPrefix("capture d") ||
               lowered.hasPrefix("bildschirmfoto") ||
               lowered.hasPrefix("captura de pantalla")
    }

    private func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "tiff", "bmp"].contains(ext)
    }
}
