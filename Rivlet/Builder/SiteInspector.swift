import AppKit

/// Fetches a page once to learn its name and find the best icon.
struct SiteInspection: Sendable {
    var finalURL: URL
    var suggestedName: String?
    var iconPNG: Data?
}

enum SiteInspector {
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    static func inspect(_ url: URL) async -> SiteInspection {
        var inspection = SiteInspection(finalURL: url)
        var candidates: [HTMLHeadParser.IconLink] = []
        if let (data, response) = try? await data(for: url), let http = response as? HTTPURLResponse {
            let finalURL = http.url ?? url
            inspection.finalURL = finalURL
            let html = String(decoding: data.prefix(400_000), as: UTF8.self)
            let parsed = HTMLHeadParser(html: html, baseURL: finalURL)
            inspection.suggestedName = parsed.suggestedName
            candidates = parsed.icons
        }
        let base = inspection.finalURL
        let fallbacks = ["/apple-touch-icon.png", "/apple-touch-icon-precomposed.png", "/favicon.ico"].compactMap {
            URL(string: $0, relativeTo: base)?.absoluteURL
        }
        for fallback in fallbacks where !candidates.contains(where: { $0.url == fallback }) {
            candidates.append(.init(url: fallback, declaredSize: fallback.lastPathComponent.hasPrefix("apple") ? 180 : 32, isAppleTouch: fallback.lastPathComponent.hasPrefix("apple")))
        }
        inspection.iconPNG = await bestIcon(from: candidates)
        return inspection
    }

    /// Tries candidates largest first and stops at the first one at least
    /// 120px wide. Falls back to the biggest thing that decoded at all.
    static func bestIcon(from candidates: [HTMLHeadParser.IconLink]) async -> Data? {
        var best: (Data, Int)?
        for candidate in candidates.prefix(8) {
            guard let (data, response) = try? await data(for: candidate.url),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                  let png = await MainActor.run(body: { normalizedPNG(data) })
            else { continue }
            if png.side >= 120 { return png.data }
            if best == nil || png.side > best!.1 { best = (png.data, png.side) }
        }
        return best?.0
    }

    @MainActor
    private static func normalizedPNG(_ data: Data) -> (data: Data, side: Int)? {
        guard let image = NSImage(data: data) else { return nil }
        let largest = image.representations.map { max($0.pixelsWide, $0.pixelsHigh) }.max() ?? Int(max(image.size.width, image.size.height))
        guard largest > 0 else { return nil }
        let side = max(largest, 64)
        guard let png = IconRenderer.pngData(image, side: min(side, 1024)) else { return nil }
        return (png, largest)
    }

    private static func data(for url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        return try await URLSession.shared.data(for: request)
    }
}
