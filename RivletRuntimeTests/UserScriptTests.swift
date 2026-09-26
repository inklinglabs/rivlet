import Foundation
import Testing
@testable import RivletRuntime

@Suite struct UserScriptTests {
    @Test func parsesHeader() {
        let source = """
        // ==UserScript==
        // @name       Hide banner
        // @include    https://mail.google.com/*
        // @match      https://*.example.com/*
        // @exclude    https://mail.google.com/settings*
        // @run-at     document-start
        // ==/UserScript==
        document.body.style.background = "red";
        """
        let script = UserScriptParser.parse(name: "file", source: source)
        #expect(script.name == "Hide banner")
        #expect(script.includes == ["https://mail.google.com/*", "https://*.example.com/*"])
        #expect(script.excludes == ["https://mail.google.com/settings*"])
        #expect(script.runAt == .documentStart)
    }

    @Test func noHeaderRunsEverywhere() {
        let script = UserScriptParser.parse(name: "plain", source: "console.log(1)")
        #expect(script.name == "plain")
        #expect(script.includes.isEmpty)
        #expect(script.runAt == .documentEnd)
    }

    @Test func globToRegex() {
        let regex = UserScriptWrapper.regexSource(forGlob: "https://*.example.com/path?x=1")
        #expect(regex == "^https:\\/\\/.*\\.example\\.com\\/path\\?x=1$")
        let compiled = try? NSRegularExpression(pattern: regex)
        #expect(compiled != nil)
        let hit = compiled?.firstMatch(in: "https://mail.example.com/path?x=1", range: NSRange(location: 0, length: 33))
        #expect(hit != nil)
    }

    @Test func wrapperContainsSourceAndGuards() {
        let script = UserScript(name: "t", source: "alert(1)", includes: ["https://a.com/*"])
        let wrapped = UserScriptWrapper.wrapped(script)
        #expect(wrapped.contains("alert(1)"))
        #expect(wrapped.contains("new RegExp"))
        #expect(wrapped.contains("catch (e)"))
    }

    @Test func jsStringEscapes() {
        #expect(UserScriptWrapper.jsString("a\"b\n") == "\"a\\\"b\\n\"")
    }
}
