import AppKit

@MainActor
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let screenshotFolder = "screenshotFolder"
        static let defaultStrokeColor = "defaultStrokeColor"
        static let defaultStrokeColorData = "defaultStrokeColorData"
        static let defaultFillColorData = "defaultFillColorData"
        static let defaultStrokeWidth = "defaultStrokeWidth"
        static let defaultShadowEnabled = "defaultShadowEnabled"
        static let stepLabelStartNumber = "stepLabelStartNumber"
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

    var defaultStrokeColor: NSColor {
        get {
            guard let data = defaults.data(forKey: Keys.defaultStrokeColorData),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            else { return .systemRed }
            return color
        }
        set {
            let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
            defaults.set(data, forKey: Keys.defaultStrokeColorData)
        }
    }

    var defaultFillColor: NSColor {
        get {
            guard let data = defaults.data(forKey: Keys.defaultFillColorData),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            else { return .clear }
            return color
        }
        set {
            let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
            defaults.set(data, forKey: Keys.defaultFillColorData)
        }
    }

    var stepLabelStartNumber: Int {
        get {
            let val = defaults.integer(forKey: Keys.stepLabelStartNumber)
            return val >= 1 ? val : 1
        }
        set { defaults.set(max(1, newValue), forKey: Keys.stepLabelStartNumber) }
    }

    private init() {}
}
