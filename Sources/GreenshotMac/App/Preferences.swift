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
        static let defaultFontSize = "defaultFontSize"
        static let defaultFontBold = "defaultFontBold"
        static let defaultFontItalic = "defaultFontItalic"
        static let defaultFontUnderline = "defaultFontUnderline"
        static let defaultFontName = "defaultFontName"
        static let defaultDashPattern = "defaultDashPattern"
        static let defaultOpacity = "defaultOpacity"
        static let defaultTextAlignment = "defaultTextAlignment"
        static let lastUsedTool = "lastUsedTool"
        static let defaultCornerRadius = "defaultCornerRadius"
        static let defaultPixelSize = "defaultPixelSize"
        static let defaultBlurRadius = "defaultBlurRadius"
        static let defaultTextVerticalAlignment = "defaultTextVerticalAlignment"
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

    var defaultFontSize: CGFloat {
        get {
            let val = defaults.double(forKey: Keys.defaultFontSize)
            return val > 0 ? val : 14.0
        }
        set { defaults.set(newValue, forKey: Keys.defaultFontSize) }
    }

    var defaultFontBold: Bool {
        get { defaults.bool(forKey: Keys.defaultFontBold) }
        set { defaults.set(newValue, forKey: Keys.defaultFontBold) }
    }

    var defaultFontItalic: Bool {
        get { defaults.bool(forKey: Keys.defaultFontItalic) }
        set { defaults.set(newValue, forKey: Keys.defaultFontItalic) }
    }

    var defaultFontUnderline: Bool {
        get { defaults.bool(forKey: Keys.defaultFontUnderline) }
        set { defaults.set(newValue, forKey: Keys.defaultFontUnderline) }
    }

    var defaultFontName: String {
        get { defaults.string(forKey: Keys.defaultFontName) ?? "Helvetica" }
        set { defaults.set(newValue, forKey: Keys.defaultFontName) }
    }

    var defaultDashPattern: String {
        get { defaults.string(forKey: Keys.defaultDashPattern) ?? DashPattern.solid.rawValue }
        set { defaults.set(newValue, forKey: Keys.defaultDashPattern) }
    }

    var defaultOpacity: CGFloat {
        get {
            let val = defaults.double(forKey: Keys.defaultOpacity)
            return val > 0 ? val : 1.0
        }
        set { defaults.set(newValue, forKey: Keys.defaultOpacity) }
    }

    var defaultTextAlignment: Int {
        get { defaults.integer(forKey: Keys.defaultTextAlignment) }
        set { defaults.set(newValue, forKey: Keys.defaultTextAlignment) }
    }

    var lastUsedTool: String? {
        get { defaults.string(forKey: Keys.lastUsedTool) }
        set { defaults.set(newValue, forKey: Keys.lastUsedTool) }
    }

    var defaultCornerRadius: CGFloat {
        get {
            let val = defaults.double(forKey: Keys.defaultCornerRadius)
            return val >= 0 ? val : 0
        }
        set { defaults.set(newValue, forKey: Keys.defaultCornerRadius) }
    }

    var defaultPixelSize: Int {
        get {
            let val = defaults.integer(forKey: Keys.defaultPixelSize)
            return val > 0 ? val : 5
        }
        set { defaults.set(newValue, forKey: Keys.defaultPixelSize) }
    }

    var defaultBlurRadius: Int {
        get {
            let val = defaults.integer(forKey: Keys.defaultBlurRadius)
            return val > 0 ? val : 10
        }
        set { defaults.set(newValue, forKey: Keys.defaultBlurRadius) }
    }

    var defaultTextVerticalAlignment: Int {
        get {
            let val = defaults.integer(forKey: Keys.defaultTextVerticalAlignment)
            return (0...2).contains(val) ? val : 1
        }
        set { defaults.set(newValue, forKey: Keys.defaultTextVerticalAlignment) }
    }

    private init() {}
}
