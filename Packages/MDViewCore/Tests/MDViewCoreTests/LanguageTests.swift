import Foundation
import Testing
@testable import MDViewCore

/// The coloured pieces of highlighted code, in order: (kind, text).
private func tokens(_ code: String, _ rules: LanguageRules) -> [(String, String)] {
    let html = Highlighter.highlight(code, rules: rules)
    return html.matches(of: /<span class="tok-([a-z]+)">([^<]*)<\/span>/).map { match in
        (String(match.1), String(match.2)
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&"))
    }
}

private func words(_ kind: String, in list: [(String, String)]) -> [String] {
    list.filter { $0.0 == kind }.map(\.1)
}

@Suite("Swift (7.1, 7.2)")
struct SwiftHighlightTests {
    @Test func typicalCode() {
        let code = """
            import Foundation

            /// Greets someone.
            @MainActor
            struct Greeter: Sendable {
                let name: String
                func greet(times: Int = 3) async throws -> String? {
                    guard times > 0 else { return nil }
                    return "Hello, \\(name)!" // interpolation stays inside the string
                }
            }
            """
        let found = tokens(code, Languages.swift)
        #expect(words("keyword", in: found) == ["import", "struct", "let", "func", "async", "throws", "guard", "else", "return", "nil", "return"])
        #expect(words("string", in: found) == [#""Hello, \(name)!""#])
        #expect(words("comment", in: found) == ["/// Greets someone.", "// interpolation stays inside the string"])
        #expect(words("number", in: found) == ["3", "0"])
    }

    @Test func multilineAndRawStrings() {
        let code = """
            let text = \"\"\"
                Line "one"
                \"\"\"
            let raw = #"no \\(escapes) "here""#
            """
        #expect(words("string", in: tokens(code, Languages.swift)) == [
            "\"\"\"\n    Line \"one\"\n    \"\"\"", ##"#"no \(escapes) "here""#"##,
        ])
    }

    @Test func nestedComments() {
        #expect(words("comment", in: tokens("/* a /* b */ c */ let x", Languages.swift)) == ["/* a /* b */ c */"])
    }

    @Test func typeNamesAreNotKeywords() {
        #expect(words("keyword", in: tokens("let s: String = Array<Int>()", Languages.swift)) == ["let"])
    }
}

@Suite("Python (7.1, 7.2)")
struct PythonHighlightTests {
    @Test func typicalCode() {
        let code = """
            # A comment
            @dataclass
            class Point:
                \"\"\"A point,
                over two lines.\"\"\"
                x: float = 0.5

                def scale(self, by=2):
                    if by is None or not by:
                        return f"zero {by}"
                    return Point(self.x * by)
            """
        let found = tokens(code, Languages.python)
        #expect(words("keyword", in: found) == ["class", "def", "if", "is", "None", "or", "not", "return", "return"])
        #expect(words("comment", in: found) == ["# A comment"])
        #expect(words("string", in: found) == ["\"\"\"A point,\n    over two lines.\"\"\"", "\"zero {by}\""])
        #expect(words("number", in: found) == ["0.5", "2"])
    }

    @Test func singleQuotedAndTripleSingle() {
        let found = tokens("a = 'it\\'s'\nb = '''x\ny'''", Languages.python)
        #expect(words("string", in: found) == ["'it\\'s'", "'''x\ny'''"])
    }

    @Test func hashInsideAStringIsNotAComment() {
        let found = tokens("url = 'https://x.y/#top'  # real comment", Languages.python)
        #expect(words("string", in: found) == ["'https://x.y/#top'"])
        #expect(words("comment", in: found) == ["# real comment"])
    }
}

@Suite("JavaScript and TypeScript (7.1, 7.2)")
struct JavaScriptHighlightTests {
    @Test func typicalJavaScript() {
        let code = """
            import { load } from "./data.js";
            /* setup */
            const $el = document.querySelector('#app');
            async function show(items = []) {
              for (const item of items) {
                $el.textContent += `${item.name}
            ` // template spans lines
              }
              return items.length > 0 ? 1_000n : null;
            }
            """
        let found = tokens(code, Languages.javaScript)
        #expect(words("keyword", in: found) == ["import", "from", "const", "async", "function", "for", "const", "of", "return", "null"])
        #expect(words("string", in: found) == ["\"./data.js\"", "'#app'", "`${item.name}\n`"])
        #expect(words("comment", in: found) == ["/* setup */", "// template spans lines"])
        #expect(words("number", in: found) == ["0", "1_000n"])
    }

    @Test func dollarIsPartOfAName() {
        #expect(words("keyword", in: tokens("let $this = this$; const if$ = 1", Languages.javaScript)) == ["let", "const"])
    }

    @Test func typeScriptAddsItsKeywords() {
        let code = "export interface User { readonly id: number; name?: string }\ntype Key = keyof User;"
        let ts = words("keyword", in: tokens(code, Languages.typeScript))
        #expect(ts == ["export", "interface", "readonly", "number", "string", "type", "keyof"])
        let js = words("keyword", in: tokens(code, Languages.javaScript))
        #expect(js == ["export"], "JavaScript doesn't know TypeScript's words")
    }

    @Test func unclosedTemplateRunsToTheEnd() {
        #expect(words("string", in: tokens("const s = `open\nstill open", Languages.javaScript)) == ["`open\nstill open"])
    }
}

@Suite("All languages: never lose text (7.6)")
struct LanguageSafetyTests {
    static let all: [(String, LanguageRules)] = [
        ("swift", Languages.swift), ("python", Languages.python),
        ("javascript", Languages.javaScript), ("typescript", Languages.typeScript),
    ]

    @Test(arguments: all.map(\.0))
    func randomInputKeepsItsText(_ name: String) throws {
        let rules = try #require(Self.all.first { $0.0 == name }?.1)
        var random = SeededRandom(seed: UInt64(name.utf8.reduce(0) { $0 &* 31 &+ UInt64($1) }))
        let pieces = ["let", "def", "func", "const", "x", "1", "0x", ".", "\"", "'", "`", "\"\"\"", "'''", "#\"", "\"#",
                      "/*", "*/", "//", "#", "\\", "\n", " ", "<", "&", "$", "${", "}", "é"]
        for index in 0..<300 {
            let code = (0..<random.next(below: 150)).map { _ in pieces[random.next(below: pieces.count)] }.joined()
            let html = Highlighter.highlight(code, rules: rules)
            let visible = html.replacing(/<[^>]+>/, with: "")
                .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&amp;", with: "&")
            #expect(visible == code, "\(name) case \(index)")
        }
    }
}
