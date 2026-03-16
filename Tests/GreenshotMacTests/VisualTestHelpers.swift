import XCTest
import AppKit
@testable import GreenshotMac

// MARK: - Rendering Helpers

/// Renders a single annotation on a solid-color background and returns the bitmap.
@MainActor
func renderAnnotation(
    _ annotation: Annotation,
    canvasSize: CGSize = CGSize(width: 400, height: 300),
    backgroundColor: NSColor = .white
) -> NSBitmapImageRep? {
    let canvas = CanvasView()
    canvas.setupUndoManager()

    let bgImage = NSImage(size: canvasSize)
    bgImage.lockFocus()
    backgroundColor.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()
    bgImage.unlockFocus()

    canvas.backgroundImage = bgImage
    canvas.frame = CGRect(origin: .zero, size: canvasSize)
    canvas.addAnnotation(annotation, isUndoAction: true)

    guard let rendered = canvas.renderFinalImage(),
          let tiff = rendered.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else {
        return nil
    }
    return bitmap
}

/// Renders multiple annotations on a solid-color background.
@MainActor
func renderAnnotations(
    _ annotations: [Annotation],
    canvasSize: CGSize = CGSize(width: 400, height: 300),
    backgroundColor: NSColor = .white
) -> NSBitmapImageRep? {
    let canvas = CanvasView()
    canvas.setupUndoManager()

    let bgImage = NSImage(size: canvasSize)
    bgImage.lockFocus()
    backgroundColor.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()
    bgImage.unlockFocus()

    canvas.backgroundImage = bgImage
    canvas.frame = CGRect(origin: .zero, size: canvasSize)
    for ann in annotations {
        canvas.addAnnotation(ann, isUndoAction: true)
    }

    guard let rendered = canvas.renderFinalImage(),
          let tiff = rendered.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else {
        return nil
    }
    return bitmap
}

/// Creates a multi-colored background (4 quadrants: red, green, blue, yellow)
/// for testing filters that need a non-uniform background.
@MainActor
func makePhotoCanvas(
    width: CGFloat = 400,
    height: CGFloat = 300
) -> CanvasView {
    let canvas = CanvasView()
    canvas.setupUndoManager()

    let bgImage = NSImage(size: NSSize(width: width, height: height))
    bgImage.lockFocus()
    let halfW = width / 2
    let halfH = height / 2
    NSColor.red.setFill()
    NSRect(x: 0, y: 0, width: halfW, height: halfH).fill()
    NSColor.green.setFill()
    NSRect(x: halfW, y: 0, width: halfW, height: halfH).fill()
    NSColor.blue.setFill()
    NSRect(x: 0, y: halfH, width: halfW, height: halfH).fill()
    NSColor.yellow.setFill()
    NSRect(x: halfW, y: halfH, width: halfW, height: halfH).fill()
    bgImage.unlockFocus()

    canvas.backgroundImage = bgImage
    canvas.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
    return canvas
}

// MARK: - Pixel Analysis Helpers

/// Extracts RGBA components (0-1) from a pixel, converting to deviceRGB.
func pixelColor(_ bitmap: NSBitmapImageRep, x: Int, y: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
    guard x >= 0, x < bitmap.pixelsWide, y >= 0, y < bitmap.pixelsHigh else { return nil }
    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return nil }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    return (r, g, b, a)
}

/// Checks if two colors match within a tolerance.
func colorsMatch(
    _ a: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat),
    _ b: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat),
    tolerance: CGFloat = 0.1
) -> Bool {
    abs(a.r - b.r) <= tolerance &&
    abs(a.g - b.g) <= tolerance &&
    abs(a.b - b.b) <= tolerance &&
    abs(a.a - b.a) <= tolerance
}

/// Converts an NSColor to RGBA tuple (deviceRGB).
/// Handles catalog colors (e.g., .systemRed) by trying multiple color spaces.
func colorToRGBA(_ color: NSColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
    // Try deviceRGB first, then sRGB, then direct extraction
    if let c = color.usingColorSpace(.deviceRGB) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    if let c = color.usingColorSpace(.sRGB) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    // Last resort: try direct extraction (may crash for some color types)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    return (r, g, b, a)
}

/// Returns coordinates of all pixels significantly different from the background color.
func nonBackgroundPixels(
    bitmap: NSBitmapImageRep,
    backgroundColor: NSColor,
    tolerance: CGFloat = 0.1
) -> [(x: Int, y: Int)] {
    let bgRGBA = colorToRGBA(backgroundColor)
    var result: [(x: Int, y: Int)] = []
    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            if let px = pixelColor(bitmap, x: x, y: y) {
                if !colorsMatch(px, bgRGBA, tolerance: tolerance) {
                    result.append((x, y))
                }
            }
        }
    }
    return result
}

/// Computes the vertical centroid of pixel positions, normalized to 0.0 (top) - 1.0 (bottom).
func verticalCentroid(of pixels: [(x: Int, y: Int)], imageHeight: Int) -> CGFloat {
    guard !pixels.isEmpty, imageHeight > 0 else { return 0.5 }
    let sum = pixels.reduce(0.0) { $0 + CGFloat($1.y) }
    let avg = sum / CGFloat(pixels.count)
    return avg / CGFloat(imageHeight)
}

/// Ratio of pixels matching a color within a rect region of the bitmap.
func filledPixelRatio(
    bitmap: NSBitmapImageRep,
    inRect rect: CGRect,
    color: NSColor,
    tolerance: CGFloat = 0.15
) -> CGFloat {
    let colorRGBA = colorToRGBA(color)
    let minX = max(0, Int(rect.minX))
    let maxX = min(bitmap.pixelsWide - 1, Int(rect.maxX))
    let minY = max(0, Int(rect.minY))
    let maxY = min(bitmap.pixelsHigh - 1, Int(rect.maxY))

    var total = 0
    var matching = 0
    for y in minY...maxY {
        for x in minX...maxX {
            total += 1
            if let px = pixelColor(bitmap, x: x, y: y) {
                if colorsMatch(px, colorRGBA, tolerance: tolerance) {
                    matching += 1
                }
            }
        }
    }
    guard total > 0 else { return 0 }
    return CGFloat(matching) / CGFloat(total)
}

// MARK: - Visual Invariant Assertions

/// Asserts that the center of a filled annotation has the expected fill color.
@MainActor
func assertFillVisible(
    _ annotation: Annotation,
    expectedColor: NSColor,
    canvasSize: CGSize = CGSize(width: 400, height: 300),
    tolerance: CGFloat = 0.15,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let bitmap = renderAnnotation(annotation, canvasSize: canvasSize) else {
        XCTFail("Failed to render annotation", file: file, line: line)
        return
    }

    let centerX = Int(annotation.bounds.midX)
    let centerY = Int(annotation.bounds.midY)
    guard let px = pixelColor(bitmap, x: centerX, y: centerY) else {
        XCTFail("Could not read pixel at (\(centerX), \(centerY))", file: file, line: line)
        return
    }

    let expected = colorToRGBA(expectedColor)
    XCTAssertTrue(
        colorsMatch(px, expected, tolerance: tolerance),
        "Fill color mismatch at center (\(centerX), \(centerY)): got rgba(\(px.r), \(px.g), \(px.b), \(px.a)), expected rgba(\(expected.r), \(expected.g), \(expected.b), \(expected.a))",
        file: file, line: line
    )
}

/// Asserts that with fill=.clear, the center pixel matches the background.
@MainActor
func assertTransparentCenter(
    _ annotation: Annotation,
    backgroundColor: NSColor = .white,
    canvasSize: CGSize = CGSize(width: 400, height: 300),
    tolerance: CGFloat = 0.1,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let bitmap = renderAnnotation(annotation, canvasSize: canvasSize, backgroundColor: backgroundColor) else {
        XCTFail("Failed to render annotation", file: file, line: line)
        return
    }

    let centerX = Int(annotation.bounds.midX)
    let centerY = Int(annotation.bounds.midY)
    guard let px = pixelColor(bitmap, x: centerX, y: centerY) else {
        XCTFail("Could not read pixel at (\(centerX), \(centerY))", file: file, line: line)
        return
    }

    let bgRGBA = colorToRGBA(backgroundColor)
    XCTAssertTrue(
        colorsMatch(px, bgRGBA, tolerance: tolerance),
        "Transparent center failed: pixel at (\(centerX), \(centerY)) is rgba(\(px.r), \(px.g), \(px.b), \(px.a)), expected background rgba(\(bgRGBA.r), \(bgRGBA.g), \(bgRGBA.b), \(bgRGBA.a))",
        file: file, line: line
    )
}

/// Asserts that pixels along the edges have the expected stroke color.
@MainActor
func assertStrokeVisible(
    _ annotation: Annotation,
    expectedColor: NSColor,
    canvasSize: CGSize = CGSize(width: 400, height: 300),
    tolerance: CGFloat = 0.15,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let bitmap = renderAnnotation(annotation, canvasSize: canvasSize) else {
        XCTFail("Failed to render annotation", file: file, line: line)
        return
    }

    let expected = colorToRGBA(expectedColor)
    let bounds = annotation.bounds
    let sw = max(1, Int(annotation.style.strokeWidth))

    // Sample multiple points along each edge, scanning inward to find the stroke
    var foundStroke = false
    let scanRange = -sw...sw

    // Midpoints of each edge
    let edgeMidpoints: [(Int, Int)] = [
        (Int(bounds.midX), Int(bounds.minY)),     // top edge
        (Int(bounds.midX), Int(bounds.maxY)),     // bottom edge
        (Int(bounds.minX), Int(bounds.midY)),     // left edge
        (Int(bounds.maxX), Int(bounds.midY)),     // right edge
    ]

    outer: for (baseX, baseY) in edgeMidpoints {
        for dy in scanRange {
            for dx in scanRange {
                let x = baseX + dx
                let y = baseY + dy
                if let px = pixelColor(bitmap, x: x, y: y) {
                    if colorsMatch(px, expected, tolerance: tolerance) {
                        foundStroke = true
                        break outer
                    }
                }
            }
        }
    }

    XCTAssertTrue(
        foundStroke,
        "No stroke pixel matching expected color found on edges of annotation at \(bounds)",
        file: file, line: line
    )
}

/// Asserts that no significant content exists outside the annotation's bounding box.
/// Detects overflow (e.g., text spilling out of a StepLabel circle).
@MainActor
func assertContentContained(
    _ annotation: Annotation,
    canvasSize: CGSize = CGSize(width: 400, height: 300),
    backgroundColor: NSColor = .white,
    margin: CGFloat = 4,
    tolerance: CGFloat = 0.1,
    maxOverflowRatio: CGFloat = 0.01,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    // Account for shadow extending beyond bounds
    let shadowMargin: CGFloat = annotation.style.shadow.enabled ? 15 : 0
    let totalMargin = margin + shadowMargin

    guard let bitmap = renderAnnotation(annotation, canvasSize: canvasSize, backgroundColor: backgroundColor) else {
        XCTFail("Failed to render annotation", file: file, line: line)
        return
    }

    let bgRGBA = colorToRGBA(backgroundColor)
    let bounds = annotation.bounds
    let expandedBounds = bounds.insetBy(dx: -totalMargin, dy: -totalMargin)

    var outsidePixels = 0
    var totalOutsidePixels = 0

    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
            if !expandedBounds.contains(point) {
                totalOutsidePixels += 1
                if let px = pixelColor(bitmap, x: x, y: y) {
                    if !colorsMatch(px, bgRGBA, tolerance: tolerance) {
                        outsidePixels += 1
                    }
                }
            }
        }
    }

    guard totalOutsidePixels > 0 else { return }
    let overflowRatio = CGFloat(outsidePixels) / CGFloat(totalOutsidePixels)

    XCTAssertLessThanOrEqual(
        overflowRatio,
        maxOverflowRatio,
        "Content overflow detected: \(outsidePixels) non-background pixels (\(String(format: "%.2f%%", overflowRatio * 100))) found outside bounds \(bounds) + margin \(totalMargin)px",
        file: file, line: line
    )
}

/// Asserts that rendering the same annotation at different sizes produces consistent
/// vertical orientation (centroid doesn't flip). Detects text-upside-down bugs.
@MainActor
func assertOrientationStable(
    annotationFactory: (CGRect) -> Annotation,
    sizes: [CGSize] = [CGSize(width: 60, height: 60), CGSize(width: 120, height: 80), CGSize(width: 200, height: 150)],
    backgroundColor: NSColor = .white,
    maxCentroidDelta: CGFloat = 0.2,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    var centroids: [CGFloat] = []

    for size in sizes {
        let canvasSize = CGSize(width: size.width + 100, height: size.height + 100)
        let bounds = CGRect(x: 50, y: 50, width: size.width, height: size.height)
        let annotation = annotationFactory(bounds)

        guard let bitmap = renderAnnotation(annotation, canvasSize: canvasSize, backgroundColor: backgroundColor) else {
            XCTFail("Failed to render at size \(size)", file: file, line: line)
            return
        }

        // Get non-background pixels within the annotation bounds only
        let bgRGBA = colorToRGBA(backgroundColor)
        var contentPixels: [(x: Int, y: Int)] = []
        let minX = max(0, Int(bounds.minX))
        let maxX = min(bitmap.pixelsWide - 1, Int(bounds.maxX))
        let minY = max(0, Int(bounds.minY))
        let maxY = min(bitmap.pixelsHigh - 1, Int(bounds.maxY))

        for y in minY...maxY {
            for x in minX...maxX {
                if let px = pixelColor(bitmap, x: x, y: y) {
                    if !colorsMatch(px, bgRGBA, tolerance: 0.1) {
                        // Normalize to annotation-local coordinates
                        contentPixels.append((x: x - minX, y: y - minY))
                    }
                }
            }
        }

        guard !contentPixels.isEmpty else { continue }

        let localHeight = maxY - minY + 1
        let centroid = verticalCentroid(of: contentPixels, imageHeight: localHeight)
        centroids.append(centroid)
    }

    guard centroids.count >= 2 else { return }

    // Check that all centroids are within maxCentroidDelta of each other
    let minCentroid = centroids.min()!
    let maxCentroid = centroids.max()!
    let delta = maxCentroid - minCentroid

    XCTAssertLessThanOrEqual(
        delta,
        maxCentroidDelta,
        "Orientation unstable: vertical centroids vary by \(String(format: "%.3f", delta)) across sizes (centroids: \(centroids.map { String(format: "%.3f", $0) })). Content may be flipping.",
        file: file, line: line
    )
}

/// Asserts that the vertical position of content matches the requested alignment.
@MainActor
func assertVerticalAlignment(
    _ annotation: Annotation,
    expected: TextVerticalAlignment,
    canvasSize: CGSize = CGSize(width: 400, height: 300),
    backgroundColor: NSColor = .white,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let bitmap = renderAnnotation(annotation, canvasSize: canvasSize, backgroundColor: backgroundColor) else {
        XCTFail("Failed to render annotation", file: file, line: line)
        return
    }

    let bgRGBA = colorToRGBA(backgroundColor)
    let bounds = annotation.bounds
    var contentPixels: [(x: Int, y: Int)] = []

    let minX = max(0, Int(bounds.minX))
    let maxX = min(bitmap.pixelsWide - 1, Int(bounds.maxX))
    let minY = max(0, Int(bounds.minY))
    let maxY = min(bitmap.pixelsHigh - 1, Int(bounds.maxY))

    for y in minY...maxY {
        for x in minX...maxX {
            if let px = pixelColor(bitmap, x: x, y: y) {
                if !colorsMatch(px, bgRGBA, tolerance: 0.1) {
                    contentPixels.append((x: x - minX, y: y - minY))
                }
            }
        }
    }

    // Filter out border/stroke pixels by looking at interior only
    let insetPx = Int(annotation.style.strokeWidth) + 3
    let interiorPixels = contentPixels.filter { px in
        px.x > insetPx && px.x < (maxX - minX - insetPx) &&
        px.y > insetPx && px.y < (maxY - minY - insetPx)
    }

    guard !interiorPixels.isEmpty else {
        // No interior content to check alignment of (may be an empty text box)
        return
    }

    let localHeight = maxY - minY + 1
    let centroid = verticalCentroid(of: interiorPixels, imageHeight: localHeight)

    switch expected {
    case .top:
        XCTAssertLessThan(
            centroid, 0.45,
            "Vertical alignment .top: centroid at \(String(format: "%.3f", centroid)), expected < 0.45",
            file: file, line: line
        )
    case .center:
        XCTAssertGreaterThan(
            centroid, 0.25,
            "Vertical alignment .center: centroid at \(String(format: "%.3f", centroid)), expected > 0.25",
            file: file, line: line
        )
        XCTAssertLessThan(
            centroid, 0.75,
            "Vertical alignment .center: centroid at \(String(format: "%.3f", centroid)), expected < 0.75",
            file: file, line: line
        )
    case .bottom:
        XCTAssertGreaterThan(
            centroid, 0.55,
            "Vertical alignment .bottom: centroid at \(String(format: "%.3f", centroid)), expected > 0.55",
            file: file, line: line
        )
    }
}

/// Asserts that the interior of a filled shape is uniform (no artifacts, shadow bleed, or drawing debris).
/// Samples a grid of pixels inside the shape's bounds (inset from edges) and checks that they
/// all match the expected fill color. Artifacts like shadow bleeding inside a speech bubble
/// or tail lines visible through the fill will cause mismatches.
@MainActor
func assertInteriorUniform(
    _ annotation: Annotation,
    expectedColor: NSColor,
    canvasSize: CGSize = CGSize(width: 400, height: 300),
    backgroundColor: NSColor = .white,
    inset: CGFloat = 10,
    tolerance: CGFloat = 0.15,
    maxArtifactRatio: CGFloat = 0.02,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let bitmap = renderAnnotation(annotation, canvasSize: canvasSize, backgroundColor: backgroundColor) else {
        XCTFail("Failed to render annotation", file: file, line: line)
        return
    }

    let interiorRect = annotation.bounds.insetBy(dx: inset, dy: inset)
    guard interiorRect.width > 0, interiorRect.height > 0 else { return }

    let expectedRGBA = colorToRGBA(expectedColor)
    var totalPixels = 0
    var artifactPixels = 0

    let minX = max(0, Int(interiorRect.minX))
    let maxX = min(bitmap.pixelsWide - 1, Int(interiorRect.maxX))
    let minY = max(0, Int(interiorRect.minY))
    let maxY = min(bitmap.pixelsHigh - 1, Int(interiorRect.maxY))

    for y in minY...maxY {
        for x in minX...maxX {
            totalPixels += 1
            if let px = pixelColor(bitmap, x: x, y: y) {
                if !colorsMatch(px, expectedRGBA, tolerance: tolerance) {
                    artifactPixels += 1
                }
            }
        }
    }

    guard totalPixels > 0 else { return }
    let artifactRatio = CGFloat(artifactPixels) / CGFloat(totalPixels)

    XCTAssertLessThanOrEqual(
        artifactRatio,
        maxArtifactRatio,
        "Interior uniformity failed: \(artifactPixels)/\(totalPixels) pixels (\(String(format: "%.1f%%", artifactRatio * 100))) don't match expected fill color. Possible shadow bleed or rendering artifacts inside shape.",
        file: file, line: line
    )
}

/// Asserts that the fill ratio of a shape matches expectations.
/// Ellipse ≈ π/4 ≈ 0.785, Rectangle ≈ 1.0
@MainActor
func assertShapeFillRatio(
    _ annotation: Annotation,
    expectedRatio: CGFloat,
    canvasSize: CGSize = CGSize(width: 400, height: 300),
    tolerance: CGFloat = 0.1,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let bitmap = renderAnnotation(annotation, canvasSize: canvasSize) else {
        XCTFail("Failed to render annotation", file: file, line: line)
        return
    }

    let ratio = filledPixelRatio(
        bitmap: bitmap,
        inRect: annotation.bounds.insetBy(dx: 2, dy: 2), // Inset to avoid anti-aliased edges
        color: annotation.style.fillColor,
        tolerance: 0.25 // Higher tolerance for CG color space conversion
    )

    XCTAssertEqual(
        ratio,
        expectedRatio,
        accuracy: tolerance,
        "Shape fill ratio: got \(String(format: "%.3f", ratio)), expected \(String(format: "%.3f", expectedRatio)) ± \(tolerance)",
        file: file, line: line
    )
}
