import Foundation

/// Pulls the title, site name, and icon links out of a page's HTML with
/// nothing more than regular expressions. Good enough for `<head>`.
struct HTMLHeadParser: Sendable {
    struct IconLink: Sendable, Equatable {
        var url: URL
        var declaredSize: Int
        var isAppleTouch: Bool
    }

    let title: String?
    let siteName: String?
    let icons: [IconLink]

    init(html: String, baseURL: URL) {
        let head = String(html.prefix(200_000))
        title = Self.decode(Self.firstMatch(in: head, pattern: #"<title[^>]*>([\s\S]*?)</title>"#))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var siteName: String?
        for tag in Self.tags(named: "meta", in: head) {
            let attrs = Self.attributes(of: tag)
            if attrs["property"]?.lowercased() == "og:site_name" || attrs["name"]?.lowercased() == "application-name" {
                siteName = Self.decode(attrs["content"])
                break
            }
        }
        self.siteName = siteName

        var icons: [IconLink] = []
        for tag in Self.tags(named: "link", in: head) {
            let attrs = Self.attributes(of: tag)
            guard let rel = attrs["rel"]?.lowercased(), let href = attrs["href"], !href.isEmpty else { continue }
            let rels = rel.split(separator: " ").map(String.init)
            let isAppleTouch = rels.contains { $0.hasPrefix("apple-touch-icon") }
            let isIcon = rels.contains("icon") || rels.contains("shortcut")
            guard isAppleTouch || isIcon else { continue }
            guard let url = URL(string: Self.decode(href) ?? href, relativeTo: baseURL)?.absoluteURL else { continue }
            var size = 0
            if let sizes = attrs["sizes"]?.lowercased(), let first = sizes.split(separator: " ").first {
                size = Int(first.split(separator: "x").first ?? "") ?? (first == "any" ? 512 : 0)
            }
            if size == 0 && isAppleTouch { size = 180 }
            if size == 0 && url.pathExtension.lowercased() == "svg" { size = 256 }
            icons.append(IconLink(url: url, declaredSize: size, isAppleTouch: isAppleTouch))
        }
        self.icons = icons.sorted { a, b in
            if a.declaredSize != b.declaredSize { return a.declaredSize > b.declaredSize }
            return a.isAppleTouch && !b.isAppleTouch
        }
    }

    /// A short name for the app from what the page says about itself.
    var suggestedName: String? {
        if let siteName, !siteName.isEmpty { return siteName }
        guard let title, !title.isEmpty else { return nil }
        let separators = [" - ", " | ", " \u{2013} ", " \u{2014} ", " \u{00B7} ", ": "]
        var parts = [title]
        for separator in separators {
            parts = parts.flatMap { $0.components(separatedBy: separator) }
        }
        let cleaned = parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard cleaned.count > 1 else { return title }
        if let last = cleaned.last, last.count <= 20 { return last }
        return cleaned.first
    }

    // MARK: Helpers

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func tags(named name: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "<\(name)\\b[^>]*>", options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    private static func attributes(of tag: String) -> [String: String] {
        var result: [String: String] = [:]
        guard let regex = try? NSRegularExpression(pattern: #"([a-zA-Z_:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))"#) else { return result }
        for match in regex.matches(in: tag, range: NSRange(tag.startIndex..., in: tag)) {
            guard let keyRange = Range(match.range(at: 1), in: tag) else { continue }
            let key = tag[keyRange].lowercased()
            for group in 2...4 {
                if let range = Range(match.range(at: group), in: tag) {
                    result[key] = String(tag[range])
                    break
                }
            }
        }
        return result
    }

    private static func decode(_ value: String?) -> String? {
        guard var text = value else { return nil }
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": " "]
        for (entity, char) in entities { text = text.replacingOccurrences(of: entity, with: char) }
        return text
    }
}
