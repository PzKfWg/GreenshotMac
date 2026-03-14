import AppKit

enum HandlePosition: CaseIterable, Sendable {
    case topLeft, topCenter, topRight
    case middleLeft, middleRight
    case bottomLeft, bottomCenter, bottomRight

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:      return CGPoint(x: rect.minX, y: rect.minY)
        case .topCenter:    return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:     return CGPoint(x: rect.maxX, y: rect.minY)
        case .middleLeft:   return CGPoint(x: rect.minX, y: rect.midY)
        case .middleRight:  return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomLeft:   return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomCenter: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomRight:  return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    var cursor: NSCursor {
        switch self {
        case .topLeft, .bottomRight:     return .crosshair
        case .topRight, .bottomLeft:     return .crosshair
        case .topCenter, .bottomCenter:  return .resizeUpDown
        case .middleLeft, .middleRight:  return .resizeLeftRight
        }
    }

    func resize(bounds: CGRect, to point: CGPoint) -> CGRect {
        var rect = bounds
        switch self {
        case .topLeft:
            rect.origin.x = point.x
            rect.origin.y = point.y
            rect.size.width = bounds.maxX - point.x
            rect.size.height = bounds.maxY - point.y
        case .topCenter:
            rect.origin.y = point.y
            rect.size.height = bounds.maxY - point.y
        case .topRight:
            rect.origin.y = point.y
            rect.size.width = point.x - bounds.minX
            rect.size.height = bounds.maxY - point.y
        case .middleLeft:
            rect.origin.x = point.x
            rect.size.width = bounds.maxX - point.x
        case .middleRight:
            rect.size.width = point.x - bounds.minX
        case .bottomLeft:
            rect.origin.x = point.x
            rect.size.width = bounds.maxX - point.x
            rect.size.height = point.y - bounds.minY
        case .bottomCenter:
            rect.size.height = point.y - bounds.minY
        case .bottomRight:
            rect.size.width = point.x - bounds.minX
            rect.size.height = point.y - bounds.minY
        }
        return rect.standardized
    }
}
