import AppKit

struct ShadowStyle: Equatable, Sendable {
    var enabled: Bool
    var offset: CGSize
    var blurRadius: CGFloat
    var color: NSColor

    static let `default` = ShadowStyle(
        enabled: true,
        offset: CGSize(width: 2, height: -2),
        blurRadius: 4,
        color: NSColor.black.withAlphaComponent(0.5)
    )

    static let none = ShadowStyle(
        enabled: false,
        offset: .zero,
        blurRadius: 0,
        color: .clear
    )

    func apply(to context: CGContext) {
        guard enabled else {
            context.setShadow(offset: .zero, blur: 0, color: nil)
            return
        }
        context.setShadow(offset: offset, blur: blurRadius, color: color.cgColor)
    }
}
