import Cocoa

func generateiOSAppIcon() {
    let size: CGFloat = 1024
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue // Pure opaque RGB for iOS App Store compliance
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: Int(size) * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Could not create CGContext")
    }

    let _ = CGRect(x: 0, y: 0, width: size, height: size)

    // 1. Deep Obsidian Titanium Background (Edge-to-Edge Full Bleed — iOS applies mask)
    let bgColors = [
        CGColor(red: 0.08, green: 0.095, blue: 0.13, alpha: 1.0),
        CGColor(red: 0.025, green: 0.028, blue: 0.04, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: size * 0.5, y: size),
            end: CGPoint(x: size * 0.5, y: 0),
            options: []
        )
    }

    let cx = size / 2.0
    let cy = size / 2.0

    // 2. Subtle Radial Ambient Halo
    let haloColors = [
        CGColor(red: 0.0, green: 0.85, blue: 0.96, alpha: 0.14),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    if let halo = CGGradient(colorsSpace: colorSpace, colors: haloColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            halo,
            startCenter: CGPoint(x: cx, y: cy),
            startRadius: 20,
            endCenter: CGPoint(x: cx, y: cy),
            endRadius: 430,
            options: []
        )
    }

    // Helper for drawing crisp glowing biometric rings
    func drawRing(radius: CGFloat, lineWidth: CGFloat, startDeg: CGFloat, endDeg: CGFloat, color: CGColor, trackAlpha: CGFloat) {
        ctx.saveGState()
        // Faint track
        ctx.setStrokeColor(color.copy(alpha: trackAlpha) ?? color)
        ctx.setLineWidth(lineWidth)
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        // Active glowing arc
        ctx.setLineCap(.round)
        ctx.setShadow(offset: .zero, blur: 18, color: color.copy(alpha: 0.45))
        ctx.setStrokeColor(color)
        ctx.setLineWidth(lineWidth)
        let sRad = startDeg * .pi / 180.0
        let eRad = endDeg * .pi / 180.0
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: radius, startAngle: sRad, endAngle: eRad, clockwise: true)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // 3. Three Precision Concentric Hardware Rings
    // Move (Apple Crimson), Exercise (Electric Lime), Stand (Arctic Cyan)
    let outerR: CGFloat = 340
    let midR: CGFloat = 278
    let innerR: CGFloat = 216

    drawRing(
        radius: outerR,
        lineWidth: 42,
        startDeg: 90,
        endDeg: -165,
        color: CGColor(red: 0.98, green: 0.07, blue: 0.31, alpha: 1.0),
        trackAlpha: 0.16
    )

    drawRing(
        radius: midR,
        lineWidth: 42,
        startDeg: 90,
        endDeg: -120,
        color: CGColor(red: 0.62, green: 0.96, blue: 0.18, alpha: 1.0),
        trackAlpha: 0.16
    )

    drawRing(
        radius: innerR,
        lineWidth: 42,
        startDeg: 90,
        endDeg: -210,
        color: CGColor(red: 0.0, green: 0.84, blue: 0.96, alpha: 1.0),
        trackAlpha: 0.16
    )

    // 4. Central Sculpted Titanium/White Delta Apex Mark (Minimal, unmistakable)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.85))
    let apexPath = CGMutablePath()
    let triTopY = cy + 98
    let triBotY = cy - 72
    let triHalfW: CGFloat = 94
    apexPath.move(to: CGPoint(x: cx, y: triTopY))
    apexPath.addLine(to: CGPoint(x: cx + triHalfW, y: triBotY))
    apexPath.addLine(to: CGPoint(x: cx - triHalfW, y: triBotY))
    apexPath.closeSubpath()

    ctx.addPath(apexPath)
    ctx.clip()

    let metalColors = [
        CGColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.78, green: 0.81, blue: 0.86, alpha: 1.0)
    ] as CFArray
    if let metalGrad = CGGradient(colorsSpace: colorSpace, colors: metalColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            metalGrad,
            start: CGPoint(x: cx, y: triTopY),
            end: CGPoint(x: cx, y: triBotY),
            options: []
        )
    }
    ctx.restoreGState()

    // Inner obsidian notch for precision delta aesthetic
    ctx.saveGState()
    let innerNotch = CGMutablePath()
    innerNotch.move(to: CGPoint(x: cx, y: cy + 28))
    innerNotch.addLine(to: CGPoint(x: cx + 44, y: triBotY - 2))
    innerNotch.addLine(to: CGPoint(x: cx - 44, y: triBotY - 2))
    innerNotch.closeSubpath()
    ctx.setFillColor(CGColor(red: 0.03, green: 0.035, blue: 0.048, alpha: 1.0))
    ctx.addPath(innerNotch)
    ctx.fillPath()
    ctx.restoreGState()

    guard let cgImage = ctx.makeImage() else {
        fatalError("Could not create CGImage")
    }

    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }

    // Create Assets.xcassets structure
    let xcassets = "ios_app/Assets.xcassets"
    let iconset = "\(xcassets)/AppIcon.appiconset"
    let launchBg = "\(xcassets)/LaunchBackground.colorset"

    try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true, attributes: nil)
    try? FileManager.default.createDirectory(atPath: launchBg, withIntermediateDirectories: true, attributes: nil)

    // Write root Contents.json
    let rootContents = """
    {
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try? rootContents.write(toFile: "\(xcassets)/Contents.json", atomically: true, encoding: .utf8)

    // Write 1024x1024 icon
    try? pngData.write(to: URL(fileURLWithPath: "\(iconset)/AppIcon-1024.png"))

    let iconContents = """
    {
      "images" : [
        {
          "filename" : "AppIcon-1024.png",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try? iconContents.write(toFile: "\(iconset)/Contents.json", atomically: true, encoding: .utf8)

    // Write LaunchBackground pure black color set
    let launchContents = """
    {
      "colors" : [
        {
          "color" : {
            "color-space" : "srgb",
            "components" : {
              "alpha" : "1.000",
              "blue" : "0.000",
              "green" : "0.000",
              "red" : "0.000"
            }
          },
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try? launchContents.write(toFile: "\(launchBg)/Contents.json", atomically: true, encoding: .utf8)

    print("✓ Generated iOS AppIcon (1024x1024) & Assets.xcassets cleanly!")
}

generateiOSAppIcon()
