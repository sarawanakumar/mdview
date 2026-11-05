import Foundation
import Testing
@testable import MDViewCore

private func tokens(_ code: String, _ rules: LanguageRules) -> [(String, String)] {
    Highlighter.highlight(code, rules: rules)
        .matches(of: /<span class="tok-([a-z]+)">([^<]*)<\/span>/)
        .map { (String($0.1), String($0.2)
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")) }
}

private func words(_ kind: String, _ code: String, _ rules: LanguageRules) -> [String] {
    tokens(code, rules).filter { $0.0 == kind }.map(\.1)
}

@Suite("Shell (7.1, 7.2)")
struct ShellHighlightTests {
    static let script = """
        #!/bin/bash
        # Build and test
        set -euo pipefail
        for file in "$@"; do
          if [ -f "$file" ]; then echo 'found' # inline comment
          fi
        done
        echo "$# args, pid $$" a#b
        exit 0
        """

    @Test func keywordsStringsComments() {
        #expect(words("keyword", Self.script, Languages.shell) == ["set", "for", "in", "do", "if", "then", "echo", "fi", "done", "echo", "exit"])
        #expect(words("string", Self.script, Languages.shell) == ["\"$@\"", "\"$file\"", "'found'", "\"$# args, pid $$\""])
        #expect(words("comment", Self.script, Languages.shell) == ["#!/bin/bash", "# Build and test", "# inline comment"])
        #expect(words("number", Self.script, Languages.shell) == ["0"])
    }

    @Test func hashOnlyStartsACommentAtTheStartOfAWord() {
        #expect(words("comment", "echo ${#list} a#b $#", Languages.shell).isEmpty)
    }

    @Test func dashedWordsAreNotKeywords() {
        #expect(words("keyword", "git --if-needed do-thing", Languages.shell).isEmpty)
    }

    @Test func quotesCanSpanLines() {
        #expect(words("string", "echo \"one\ntwo\"", Languages.shell) == ["\"one\ntwo\""])
    }
}

@Suite("JSON (7.1, 7.2)")
struct JSONHighlightTests {
    @Test func typicalDocument() {
        let json = """
            {
              "name": "mdview",
              "version": 1.2e3,
              "tags": ["a\\"b", true, false, null],
              "count": -42
            }
            """
        #expect(words("string", json, Languages.json) == ["\"name\"", "\"mdview\"", "\"version\"", "\"tags\"", "\"a\\\"b\"", "\"count\""])
        #expect(words("keyword", json, Languages.json) == ["true", "false", "null"])
        #expect(words("number", json, Languages.json) == ["1.2e3", "42"])
    }

    @Test func commentsAreTolerated() {
        #expect(words("comment", "{ // note\n \"a\": 1 /* b */ }", Languages.json) == ["// note", "/* b */"])
    }
}

@Suite("YAML (7.1, 7.2)")
struct YAMLHighlightTests {
    @Test func typicalDocument() {
        let yaml = """
            # Settings
            name: mdview
            enabled: true
            retries: 3
            quoted: "a # not a comment"
            single: 'it''s'
            list:
              - on
              - off  # trailing comment
            url: http://x.y/#anchor
            """
        #expect(words("comment", yaml, Languages.yaml) == ["# Settings", "# trailing comment"])
        #expect(words("keyword", yaml, Languages.yaml) == ["true", "on", "off"])
        #expect(words("number", yaml, Languages.yaml) == ["3"])
        #expect(words("string", yaml, Languages.yaml) == ["\"a # not a comment\"", "'it'", "'s'"])
    }

    @Test func kebabKeysAreNotKeywords() {
        #expect(words("keyword", "is-on: yes", Languages.yaml) == ["yes"])
    }
}

@Suite("HTML (7.1, 7.2)")
struct HTMLHighlightTests {
    @Test func tagsAttributesComments() {
        let html = """
            <!-- page header -->
            <div class="note" data-id='7'>
              <p>Don't colour "this" or 42.</p>
              <custom-element hidden></custom-element>
            </div>
            """
        #expect(words("comment", html, Languages.html) == ["<!-- page header -->"])
        #expect(words("keyword", html, Languages.html) == ["div", "p", "p", "custom-element", "custom-element", "div"])
        #expect(words("string", html, Languages.html) == ["\"note\"", "'7'"])
        #expect(words("number", html, Languages.html).isEmpty)
    }

    @Test func spacesAroundEqualsAreFine() {
        #expect(words("string", "<a href = \"x\">", Languages.html) == ["\"x\""])
    }

    @Test func wordsInTextAreNotTags() {
        #expect(words("keyword", "a p div span b", Languages.html).isEmpty)
    }
}

@Suite("CSS (7.1, 7.2)")
struct CSSHighlightTests {
    @Test func typicalStylesheet() {
        let css = """
            /* Layout */
            @media (max-width: 600px) {
              #main .card { margin: 0 auto; color: #1f2328 !important; }
              .icon::before { content: "\\201C"; font: 1.5rem/1.2 'SF Pro'; }
            }
            """
        #expect(words("comment", css, Languages.css) == ["/* Layout */"])
        #expect(words("keyword", css, Languages.css) == ["@media", "auto", "important"])
        #expect(words("number", css, Languages.css) == ["600px", "0", "1.5rem", "1.2"])
        #expect(words("string", css, Languages.css) == ["\"\\201C\"", "'SF Pro'"])
    }

    @Test func hexColoursAndIdsStayWhole() {
        #expect(words("number", "a { color: #0a0; } #x2 {}", Languages.css).isEmpty)
    }
}

@Suite("All nine languages: never lose text (7.6)")
struct AllLanguageSafetyTests {
    static let all: [(String, LanguageRules)] = [
        ("swift", Languages.swift), ("python", Languages.python), ("javascript", Languages.javaScript),
        ("typescript", Languages.typeScript), ("shell", Languages.shell), ("json", Languages.json),
        ("yaml", Languages.yaml), ("html", Languages.html), ("css", Languages.css),
    ]

    @Test(arguments: all.map(\.0))
    func randomInputKeepsItsText(_ name: String) throws {
        let rules = try #require(Self.all.first { $0.0 == name }?.1)
        var random = SeededRandom(seed: UInt64(name.utf8.reduce(7) { $0 &* 131 &+ UInt64($1) }))
        let pieces = ["<", "</", ">", "=", "\"", "'", "`", "#", "$#", "<!--", "-->", "/*", "*/", "//", "@media", "-", "x",
                      "div", "if", "true", "1", "0x", "1.5rem", "\\", "\n", " ", "&", "é", "{", "}"]
        for index in 0..<300 {
            let code = (0..<random.next(below: 150)).map { _ in pieces[random.next(below: pieces.count)] }.joined()
            let visible = Highlighter.highlight(code, rules: rules).replacing(/<span[^>]*>|<\/span>/, with: "")
                .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&amp;", with: "&")
            #expect(visible == code, "\(name) case \(index)")
        }
    }
}
