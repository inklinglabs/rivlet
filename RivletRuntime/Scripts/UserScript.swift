import Foundation

/// One userscript file, with the Greasemonkey style header parsed out.
public struct UserScript: Sendable, Equatable {
    public enum RunAt: String, Sendable { case documentStart = "document-start", documentEnd = "document-end" }

    public var name: String
    public var source: String
    public var includes: [String]
    public var excludes: [String]
    public var runAt: RunAt

    public init(name: String, source: String, includes: [String] = [], excludes: [String] = [], runAt: RunAt = .documentEnd) {
        self.name = name
        self.source = source
        self.includes = includes
        self.excludes = excludes
        self.runAt = runAt
    }
}

public enum UserScriptParser {
    /// Reads `// ==UserScript==` ... `// ==/UserScript==` for `@name`,
    /// `@include`, `@match`, `@exclude`, and `@run-at`. Scripts with no
    /// header run on every page of the app.
    public static func parse(name fileName: String, source: String) -> UserScript {
        var script = UserScript(name: fileName, source: source)
        guard let start = source.range(of: "==UserScript=="),
              let end = source.range(of: "==/UserScript==", range: start.upperBound..<source.endIndex)
        else { return script }
        let header = source[start.upperBound..<end.lowerBound]
        for rawLine in header.split(whereSeparator: \.isNewline) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("//") else { continue }
            line = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("@") else { continue }
            let parts = line.dropFirst().split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "name": script.name = value
            case "include", "match": script.includes.append(value)
            case "exclude": script.excludes.append(value)
            case "run-at": script.runAt = UserScript.RunAt(rawValue: value) ?? .documentEnd
            default: break
            }
        }
        return script
    }
}

public enum UserScriptWrapper {
    /// Turns a glob like `https://*.google.com/*` into a JavaScript regex
    /// source. `*` matches anything, everything else is literal.
    public static func regexSource(forGlob glob: String) -> String {
        var out = "^"
        for ch in glob {
            switch ch {
            case "*": out += ".*"
            case ".", "+", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|", "\\", "/":
                out += "\\" + String(ch)
            default: out += String(ch)
            }
        }
        return out + "$"
    }

    /// Wraps the script so it only runs on matching URLs and a thrown error
    /// cannot take the page down.
    public static func wrapped(_ script: UserScript) -> String {
        let includes = script.includes.isEmpty ? ["*"] : script.includes
        let inc = includes.map { "new RegExp(\(jsString(regexSource(forGlob: $0))))" }.joined(separator: ",")
        let exc = script.excludes.map { "new RegExp(\(jsString(regexSource(forGlob: $0))))" }.joined(separator: ",")
        return """
        (function () {
          var href = location.href;
          var inc = [\(inc)];
          var exc = [\(exc)];
          if (!inc.some(function (r) { return r.test(href); })) { return; }
          if (exc.some(function (r) { return r.test(href); })) { return; }
          try {
        \(script.source)
          } catch (e) { console.error("Rivlet userscript " + \(jsString(script.name)) + " failed:", e); }
        })();
        """
    }

    public static func cssInjector(_ css: String) -> String {
        """
        (function () {
          var s = document.getElementById("rivlet-user-css");
          if (!s) { s = document.createElement("style"); s.id = "rivlet-user-css"; }
          s.textContent = \(jsString(css));
          (document.head || document.documentElement).appendChild(s);
        })();
        """
    }

    public static func jsString(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [value])
        let encoded = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(encoded.dropFirst().dropLast())
    }
}
