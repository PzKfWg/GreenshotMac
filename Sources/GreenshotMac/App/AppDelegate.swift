import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var screenshotWatcher: ScreenshotWatcher?
    private var editorWindows: [EditorWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        startScreenshotWatcher()
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pencil.and.outline",
                                   accessibilityDescription: "GreenshotMac")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Image...",
                                action: #selector(openImageFile),
                                keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Paste from Clipboard",
                                action: #selector(pasteFromClipboard),
                                keyEquivalent: "v"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...",
                                action: #selector(showPreferences),
                                keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit GreenshotMac",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Screenshot Watcher

    private func startScreenshotWatcher() {
        let watchPath = Preferences.shared.screenshotFolder
        screenshotWatcher = ScreenshotWatcher(watchPath: watchPath) { [weak self] url in
            DispatchQueue.main.async {
                self?.openEditor(with: url)
            }
        }
        screenshotWatcher?.start()
    }

    // MARK: - Editor

    func openEditor(with imageURL: URL) {
        guard let image = NSImage(contentsOf: imageURL) else { return }
        let editor = EditorWindowController(image: image, sourceURL: imageURL)
        editorWindows.append(editor)
        editor.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openEditor(with image: NSImage) {
        let editor = EditorWindowController(image: image, sourceURL: nil)
        editorWindows.append(editor)
        editor.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func editorDidClose(_ editor: EditorWindowController) {
        editorWindows.removeAll { $0 === editor }
    }

    // MARK: - Menu Actions

    @objc private func openImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            openEditor(with: url)
        }
    }

    @objc private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
              let image = images.first else { return }
        openEditor(with: image)
    }

    @objc private func showPreferences() {
        // TODO: Preferences window
    }
}
