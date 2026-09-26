import AppKit
import UniformTypeIdentifiers

/// Makes app icons: rounds a fetched site icon, draws a letter fallback,
/// and writes .icns through iconutil.
enum IconRenderer {
    static let canvas = 1024

    /// Scales the image to fill a 1024 canvas and rounds the corners the
    /// way macOS icons are rounded.
    @MainActor
    static func appIcon(from image: NSImage, roundCorners: Bool) -> NSImage {
        let size = CGFloat(canvas)
        let result = NSImage(size: NSSize(width: size, height: size))
        result.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        if roundCorners {
            NSBezierPath(roundedRect: rect, xRadius: size * 0.2237, yRadius: size * 0.2237).addClip()
        }
        let imageSize = image.size
        let scale = max(size / max(imageSize.width, 1), size / max(imageSize.height, 1))
        let drawSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = NSPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
        image.draw(in: NSRect(origin: origin, size: drawSize), from: .zero, operation: .sourceOver, fraction: 1)
        result.unlockFocus()
        return result
    }

    /// A rounded tile with the first letter of the name, colored from the host.
    @MainActor
    static func letterIcon(name: String, host: String) -> NSImage {
        let size = CGFloat(canvas)
        let result = NSImage(size: NSSize(width: size, height: size))
        result.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let hue = CGFloat(abs(host.hashValue % 360)) / 360
        NSColor(hue: hue, saturation: 0.55, brightness: 0.62, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: size * 0.2237, yRadius: size * 0.2237).fill()
        let letter = String(name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "R")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.56, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let text = NSAttributedString(string: letter, attributes: attributes)
        let textSize = text.size()
        text.draw(at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 - size * 0.02))
        result.unlockFocus()
        return result
    }

    @MainActor
    static func pngData(_ image: NSImage, side: Int) -> Data? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        rep.size = NSSize(width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    /// Writes an .icns from a 1024 PNG using iconutil.
    static func writeICNS(png: Data, to destination: URL) async throws {
        guard let source = NSImage(data: png) else { throw AppBundleError.iconFailed("The image could not be read.") }
        let iconset = FileManager.default.temporaryDirectory.appending(path: "rivlet-\(UUID().uuidString).iconset", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: iconset) }
        let entries: [(String, Int)] = [
            ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
        ]
        for (name, side) in entries {
            guard let data = await MainActor.run(body: { pngData(source, side: side) }) else {
                throw AppBundleError.iconFailed("Could not render \(side)px.")
            }
            try data.write(to: iconset.appending(path: name))
        }
        let result = try await Shell.run("/usr/bin/iconutil", ["-c", "icns", "-o", destination.path, iconset.path])
        guard result.status == 0 else { throw AppBundleError.iconFailed(result.output) }
    }
}
