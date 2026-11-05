import Foundation
import Testing
@testable import MDViewCore

/// Roadmap 6.6: `fixtures/code.md` checked block by block, and a
/// 2,000-line block timed (spec 7.3, 7.7).
@Suite("code.md and long code blocks (section 7)")
struct CodeFixtureTests {
    /// The rendered `<code>` blocks of code.md, in page order, as
    /// (class attribute or "", inner HTML).
    static func blocks() throws -> [(language: String, html: String)] {
        let html = HTMLRenderer.render(markdown: try Fixtures.text("code.md"))
        return html.matches(of: /<pre><code(?: class="language-([a-z]+)")?>(.*?)<\/code><\/pre>/.dotMatchesNewlines())
            .map { (String($0.1 ?? ""), String($0.2)) }
    }

    @Test func oneBlockPerLanguageWithAllFourColours() throws {
        let blocks = try Self.blocks()
        let languages = ["swift", "python", "javascript", "ts", "bash", "json", "yaml", "html", "css"]
        #expect(Array(blocks.prefix(languages.count).map(\.language)) == languages)
        for block in blocks.prefix(languages.count) {
            // HTML has no numbers to colour (its text stays plain on purpose),
            // and plain JSON has no comments.
            var kinds = ["keyword", "string", "comment", "number"]
            if block.language == "html" { kinds.removeAll { $0 == "number" } }
            if block.language == "json" { kinds.removeAll { $0 == "comment" } }
            for kind in kinds {
                #expect(block.html.contains("tok-\(kind)"), "\(block.language) has no \(kind)")
            }
        }
    }

    @Test func multiLineStringsAndCommentsStayInOneSpan() throws {
        let spans = try Self.blocks().flatMap { block in
            block.html.matches(of: /<span class="tok-(string|comment)">([^<]*)<\/span>/).map { String($0.2) }
        }
        let multiLine = spans.filter { $0.contains("\n") }
        #expect(multiLine.count >= 6, "Swift, Python, JavaScript and HTML have multi-line spans, plus the broken blocks")
    }

    @Test func plainBlocksHaveNoColour() throws {
        let plain = try Self.blocks().filter { ["", "cobol"].contains($0.language) }
        #expect(plain.count == 3)
        for block in plain { #expect(!block.html.contains("tok-")) }
    }

    @Test func brokenBlocksDoNotSpillOut() throws {
        let html = HTMLRenderer.render(markdown: try Fixtures.text("code.md"))
        #expect(html.hasSuffix("<p>The text after the broken blocks is still normal.</p>\n"))
        #expect(html.components(separatedBy: "<span").count == html.components(separatedBy: "</span>").count)
    }

    // MARK: 2,000 lines (7.7)

    /// About 2,000 lines of realistic Swift, with strings and comments.
    static let longBlock: String = {
        let piece = """
            /// Loads item \\(index).
            func load(_ index: Int) throws -> String? {
                let name = "item-\\(index)" // a name
                /* retry a few times */
                for attempt in 0..<3 where attempt > 0x0 {
                    if index.isMultiple(of: 2) { return nil }
                }
                return name + #"raw "text""#
            }

            """
        return "# Long\n\n```swift\n" + String(repeating: piece, count: 225) + "```\n"
    }()

    @Test func theLongBlockIsLong() {
        #expect(Self.longBlock.components(separatedBy: "\n").count > 2_000)
    }

    @Test func aTwoThousandLineBlockRendersQuickly() {
        _ = HTMLRenderer.render(markdown: Self.longBlock)  // warm up
        let clock = ContinuousClock()
        var times: [Duration] = []
        for _ in 0..<5 {
            times.append(clock.measure { _ = HTMLRenderer.render(markdown: Self.longBlock) })
        }
        let median = times.sorted()[2]
        print("2,000-line Swift block: median render \(median)")
        // Spec 8 is measured on release builds, where this takes about 10 ms.
        // Tests usually run as debug builds, several times slower, so this
        // only catches a large slowdown, such as work that grows with the
        // square of the block's length. The real check is in the app.
        #expect(median < .milliseconds(500))
    }
}
