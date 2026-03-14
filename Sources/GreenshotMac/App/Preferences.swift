import Foundation

@MainActor
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let screenshotFolder = "screenshotFolder"
        static let defaultStrokeColor = "defaultStrokeColor"
        static let defaultStrokeWidth = "defaultStrokeWidth"
        static let defaultShadowEnabled = "defaultShadowEnabled"
    }

    var screenshotFolder: String {
        get {
            defaults.string(forKey: Keys.screenshotFolder)
                ?? NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first
                ?? "~/Desktop"
        }
        set { defaults.set(newValue, forKey: Keys.screenshotFolder) }
    }

    var defaultStrokeWidth: CGFloat {
        get {
            let val = defaults.double(forKey: Keys.defaultStrokeWidth)
            return val > 0 ? val : 2.0
        }
        set { defaults.set(newValue, forKey: Keys.defaultStrokeWidth) }
    }

    var defaultShadowEnabled: Bool {
        get { defaults.bool(forKey: Keys.defaultShadowEnabled) }
        set { defaults.set(newValue, forKey: Keys.defaultShadowEnabled) }
    }

    private init() {}
}
