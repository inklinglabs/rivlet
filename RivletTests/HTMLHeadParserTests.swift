import Foundation
import Testing
@testable import Rivlet

@Suite struct HTMLHeadParserTests {
    let base = URL(string: "https://example.com/app/")!

    @Test func findsTitleSiteNameAndIcons() {
        let html = """
        <html><head>
        <title>Inbox (2) - Example &amp; Co</title>
        <meta property="og:site_name" content="Example Mail">
        <link rel="icon" href="/favicon.ico" sizes="32x32">
        <link rel="apple-touch-icon" sizes="180x180" href="icons/touch.png">
        <link rel='shortcut icon' href='//cdn.example.com/i.png'>
        </head><body></body></html>
        """
        let parsed = HTMLHeadParser(html: html, baseURL: base)
        #expect(parsed.title == "Inbox (2) - Example & Co")
        #expect(parsed.siteName == "Example Mail")
        #expect(parsed.suggestedName == "Example Mail")
        #expect(parsed.icons.first?.url.absoluteString == "https://example.com/app/icons/touch.png")
        #expect(parsed.icons.map(\.url.absoluteString).contains("https://cdn.example.com/i.png"))
        #expect(parsed.icons.count == 3)
    }

    @Test func suggestsNameFromTitle() {
        #expect(HTMLHeadParser(html: "<title>Inbox - user@x.com - Gmail</title>", baseURL: base).suggestedName == "Gmail")
        #expect(HTMLHeadParser(html: "<title>Notion</title>", baseURL: base).suggestedName == "Notion")
        #expect(HTMLHeadParser(html: "<title>Slack | general | Workspace name that is quite long indeed</title>", baseURL: base).suggestedName == "Slack")
        #expect(HTMLHeadParser(html: "<head></head>", baseURL: base).suggestedName == nil)
    }
}
