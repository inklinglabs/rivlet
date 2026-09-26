import Foundation
import Testing
@testable import RivletRuntime

@Suite struct NavigationPolicyTests {
    let gmail = NavigationPolicy(appURL: URL(string: "https://mail.google.com/mail/u/0/")!, allowedHosts: [".googleusercontent.com"])

    @Test func registrableDomains() {
        #expect(NavigationPolicy.registrableDomain(of: "mail.google.com") == "google.com")
        #expect(NavigationPolicy.registrableDomain(of: "www.bbc.co.uk") == "bbc.co.uk")
        #expect(NavigationPolicy.registrableDomain(of: "localhost") == "localhost")
        #expect(NavigationPolicy.registrableDomain(of: "10.0.0.5") == "10.0.0.5")
        #expect(NavigationPolicy.registrableDomain(of: "a.b.c.example.com") == "example.com")
    }

    @Test func sameDomainStays() {
        #expect(gmail.decision(for: URL(string: "https://calendar.google.com/")!, isUserLinkClick: true) == .stayInApp)
    }

    @Test func allowedSuffixStays() {
        #expect(gmail.decision(for: URL(string: "https://lh3.googleusercontent.com/x.png")!, isUserLinkClick: true) == .stayInApp)
        #expect(gmail.decision(for: URL(string: "https://googleusercontent.com/")!, isUserLinkClick: true) == .stayInApp)
    }

    @Test func foreignLinkClickGoesOutside() {
        #expect(gmail.decision(for: URL(string: "https://example.com/article")!, isUserLinkClick: true) == .openExternally)
    }

    @Test func foreignRedirectStays() {
        #expect(gmail.decision(for: URL(string: "https://example.com/callback")!, isUserLinkClick: false) == .stayInApp)
    }

    @Test func signInHostsAlwaysAllowed() {
        let app = NavigationPolicy(appURL: URL(string: "https://app.example.com")!, allowedHosts: [])
        #expect(app.decision(for: URL(string: "https://accounts.google.com/o/oauth2")!, isUserLinkClick: true) == .stayInApp)
        #expect(app.decision(for: URL(string: "https://dev-123.okta.com/login")!, isUserLinkClick: true) == .stayInApp)
    }

    @Test func nonWebSchemesGoOutside() {
        #expect(gmail.decision(for: URL(string: "mailto:someone@example.com")!, isUserLinkClick: false) == .openExternally)
        #expect(gmail.decision(for: URL(string: "about:blank")!, isUserLinkClick: true) == .stayInApp)
    }

    @Test func seedsForGoogle() {
        let seeds = NavigationPolicy.seededAllowedHosts(for: URL(string: "https://mail.google.com")!)
        #expect(seeds.contains(".google.com"))
        #expect(NavigationPolicy.seededAllowedHosts(for: URL(string: "https://example.com")!).isEmpty)
    }
}
