import AppKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    var onFolderChanged: (() -> Void)?

    private let pathLabel = NSTextField(labelWithString: "")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 130),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Préférences"
        window.center()
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "Dossier de captures d'écran :")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        pathLabel.font = .systemFont(ofSize: 12)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.stringValue = Preferences.shared.screenshotFolder

        let chooseButton = NSButton(title: "Choisir…", target: self, action: #selector(chooseFolder))
        chooseButton.bezelStyle = .rounded

        let stack = NSStackView(views: [titleLabel, pathLabel, chooseButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choisir"
        panel.message = "Choisissez le dossier à surveiller pour les captures d'écran"

        guard let window = self.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Preferences.shared.screenshotFolder = url.path
            self?.pathLabel.stringValue = url.path
            self?.onFolderChanged?()
        }
    }
}
