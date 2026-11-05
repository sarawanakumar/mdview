import Foundation
import Testing
@testable import MDViewCore

/// A made-up language that uses every rule, so the scanner is tested apart
/// from any real language (those come in roadmap 6.2, 6.3).
private let testRules = LanguageRules(
    keywords: ["let", "if", "return", "func"],
    lineComments: ["//"],
    blockComments: [.init(open: "/*", close: "*/", nests: true)],
    strings: [
        .init(open: "\""),
        .init(open: "'", escape: nil),
        .init(open: "\"\"\"", spansLines: true),
    ],
    wordCharacters: ["$"]
)

private func colour(_ code: String, _ rules: LanguageRules = testRules) -> String {
    Highlighter.highlight(code, rules: rules)
}

private func span(_ kind: String, _ text: String) -> String {
    "<span class=\"tok-\(kind)\">\(text)</span>"
}

/// The text a reader sees: tags removed, entities decoded.
private func visibleText(_ html: String) -> String {
    html.replacing(/<[^>]+>/, with: "")
        .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
}

@Suite("Highlighter: the four token kinds (7.2)")
struct HighlighterTokenTests {
    @Test func keywords() {
        #expect(colour("let x") == span("keyword", "let") + " x")
    }

    @Test func keywordsOnlyAsWholeWords() {
        #expect(colour("letter iffy _let let_ $if") == "letter iffy _let let_ $if")
    }

    @Test func lineComment() {
        #expect(colour("x // note\ny") == "x " + span("comment", "// note") + "\ny")
    }

    @Test func blockCommentAcrossLines() {
        #expect(colour("a /* one\ntwo */ b") == "a " + span("comment", "/* one\ntwo */") + " b")
    }

    @Test func nestedBlockComment() {
        #expect(colour("/* a /* b */ c */ d") == span("comment", "/* a /* b */ c */") + " d")
    }

    @Test func stringsWithEscapes() {
        #expect(colour(#"say("a \"quoted\" word")"#) == "say(" + span("string", #"&quot;a \&quot;quoted\&quot; word&quot;"#) + ")")
    }

    @Test func stringWithoutEscapes() {
        #expect(colour(#"'a\' b"#) == span("string", #"&#39;a\&#39;"#) + " b")
    }

    @Test func multilineStringWinsOverSingle() {
        #expect(colour("\"\"\"\nline \"one\"\n\"\"\" x") == span("string", "&quot;&quot;&quot;\nline &quot;one&quot;\n&quot;&quot;&quot;") + " x")
    }

    @Test(arguments: ["42", "3.14", "0x1F", "0b1010", "0o17", "1_000_000", "6.02e23", "1e-9", ".5", "10px", "3n", "1.5f"])
    func numbers(_ number: String) {
        #expect(colour("x = \(number);") == "x = " + span("number", number) + ";")
    }

    @Test func digitsInsideWordsAreNotNumbers() {
        #expect(colour("x1 v2_beta $3") == "x1 v2_beta $3")
    }

    @Test func numberThenMethod() {
        #expect(colour("1.description") == span("number", "1") + ".description")
    }

    @Test func commentsAndStringsHideWhatsInside() {
        #expect(colour(#"// let "s" 42"#) == span("comment", #"// let &quot;s&quot; 42"#))
        #expect(colour(#""let // 42""#) == span("string", #"&quot;let // 42&quot;"#))
    }

    @Test func everythingIsEscaped() {
        #expect(colour("if a < b && c > d { return \"<b>\" }")
            == span("keyword", "if") + " a &lt; b &amp;&amp; c &gt; d { " + span("keyword", "return") + " " + span("string", "&quot;&lt;b&gt;&quot;") + " }")
    }

    @Test func unicodeWordsAndText() {
        #expect(colour("let café = \"日本\" // ✓") == span("keyword", "let") + " café = " + span("string", "&quot;日本&quot;") + " " + span("comment", "// ✓"))
    }

    @Test func noRulesMeansNoColour() {
        #expect(colour("let x = 1 // c", LanguageRules(highlightsNumbers: false)) == "let x = 1 // c")
    }
}

@Suite("Highlighter: broken code never breaks it (7.6)")
struct HighlighterMalformedTests {
    @Test func unclosedStringStopsAtTheEndOfItsLine() {
        #expect(colour("a = \"open\nlet b") == "a = " + span("string", "&quot;open") + "\n" + span("keyword", "let") + " b")
    }

    @Test func unclosedMultilineStringRunsToTheEnd() {
        #expect(colour("\"\"\"\nlet x\n") == span("string", "&quot;&quot;&quot;\nlet x\n"))
    }

    @Test func unclosedBlockCommentRunsToTheEnd() {
        #expect(colour("a /* let\nb") == "a " + span("comment", "/* let\nb"))
    }

    @Test func escapeAtTheVeryEnd() {
        #expect(colour("\"abc\\") == span("string", "&quot;abc\\"))
    }

    @Test(arguments: ["", "\"", "/*", "//", "\"\"\"", "*/", "0x", "1e", ".", "\\", "'", "$", "\n\n"])
    func tinyAndOddInputs(_ code: String) {
        #expect(visibleText(colour(code)) == code)
    }

    @Test func manyUnclosedOpenersFinishQuickly() {
        let code = String(repeating: "/* \" ''' 0x .5e+ // \n", count: 5_000)
        let clock = ContinuousClock()
        var html = ""
        let elapsed = clock.measure { html = colour(code) }
        #expect(elapsed < .seconds(1))
        #expect(visibleText(html) == code)
    }

    /// The scanner never adds, drops or changes text: only spans and escapes.
    @Test func randomInputKeepsExactlyItsText() {
        var random = SeededRandom(seed: 99)
        let pieces = ["let", "if", "x", "1", "0x", ".", "e", "+", "\"", "'", "\"\"\"", "/*", "*/", "//", "\\", "\n", " ", "<", "&", "$", "é", "🎉"]
        for index in 0..<500 {
            let code = (0..<random.next(below: 200)).map { _ in pieces[random.next(below: pieces.count)] }.joined()
            #expect(visibleText(colour(code)) == code, "case \(index)")
        }
    }
}
