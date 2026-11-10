import Cocoa

func makeAppIcon() {
    let size: CGFloat = 1024
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    // 1. Dark Obsidian Titanium Rounded Background
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let clipPath = NSBezierPath(roundedRect: rect.insetBy(dx: 48, dy: 48), xRadius: 220, yRadius: 220)
    clipPath.addClip()

    // Dark gradient background
    let gradient = NSGradient(
        starting: NSColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0),
        ending: NSColor(red: 0.02, green: 0.03, blue: 0.04, alpha: 1.0)
    )!
    gradient.draw(in: rect, angle: -45)

    // Gold/Volt Rim border
    let borderPath = NSBezierPath(roundedRect: rect.insetBy(dx: 52, dy: 52), xRadius: 216, yRadius: 216)
    NSColor(red: 0.90, green: 0.99, blue: 0.25, alpha: 0.4).setStroke()
    borderPath.lineWidth = 12
    borderPath.stroke()

    // 2. Neon Cyan Ambient Glow
    let glowPath = NSBezierPath(ovalIn: NSRect(x: 262, y: 262, width: 500, height: 500))
    NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.15).setFill()
    glowPath.fill()

    // 3. Central Volt Triangle Logo "▲"
    let triangle = NSBezierPath()
    let cx = size / 2
    let cy = size / 2 - 20
    triangle.move(to: NSPoint(x: cx, y: cy + 220))
    triangle.line(to: NSPoint(x: cx + 200, y: cy - 160))
    triangle.line(to: NSPoint(x: cx - 200, y: cy - 160))
    triangle.close()

    // Triangle drop shadow
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
    shadow.shadowOffset = NSSize(width: 0, height: -20)
    shadow.shadowBlurRadius = 30
    shadow.set()

    // Fill Volt Neon
    NSColor(red: 0.90, green: 0.99, blue: 0.25, alpha: 1.0).setFill()
    triangle.fill()

    // Dark inner accent triangle
    let innerTriangle = NSBezierPath()
    innerTriangle.move(to: NSPoint(x: cx, y: cy + 120))
    innerTriangle.line(to: NSPoint(x: cx + 110, y: cy - 100))
    innerTriangle.line(to: NSPoint(x: cx - 110, y: cy - 100))
    innerTriangle.close()
    NSColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1.0).setFill()
    innerTriangle.fill()

    img.unlockFocus()

    // Write PNG
    let tiff = img.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    let png = rep.representation(using: .png, properties: [:])!

    let iconsetDir = "AppIcon.iconset"
    try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true, attributes: nil)

    let sizes: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for (name, s) in sizes {
        let resized = NSImage(size: NSSize(width: s, height: s))
        resized.lockFocus()
        img.draw(in: NSRect(x: 0, y: 0, width: s, height: s), from: .zero, operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        let tiffResized = resized.tiffRepresentation!
        let repResized = NSBitmapImageRep(data: tiffResized)!
        let pngResized = repResized.representation(using: .png, properties: [:])!
        try? pngResized.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name)"))
    }

    print("Generated AppIcon.iconset successfully")
}

makeAppIcon()
