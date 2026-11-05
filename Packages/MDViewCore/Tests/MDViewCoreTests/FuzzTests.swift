import Foundation
import Testing
@testable import MDViewCore

/// Spec 10.4: any Markdown input, however malformed, renders something and
/// never crashes or hangs (roadmap 2.9).
///
/// Inputs come from a seeded generator, so a failure names a seed and case
/// number that reproduce it exactly.
@Suite("Fuzz (10.4)")
struct FuzzTests {
    /// Longest any single input may take, well under spec 8.3's 2 s for a
    /// whole 5 MB file (these inputs are at most a few hundred KB).
    static let timeLimit: Duration = .seconds(2)

    /// Renders through the same path as the app and checks the result.
    private func check(_ markdown: String, _ label: @autoclosure () -> String) async {
        let clock = ContinuousClock()
        var html = ""
        let elapsed = await clock.measure {
            html = await HTMLRenderer.renderSafely(markdown: markdown).html
        }
        // Something must show, unless there's nothing to show: a blank file,
        // or one that is only front matter (hidden, spec 2.13).
        if FrontMatter.strip(markdown).contains(where: { !$0.isWhitespace }) {
            #expect(!html.isEmpty, "\(label()): empty output")
        }
        #expect(elapsed < Self.timeLimit, "\(label()): took \(elapsed)")
    }

    // MARK: Generated input

    @Test func randomMarkdownFragments() async {
        var random = SeededRandom(seed: 0x6D64_7669_6577)  // "mdview"
        for index in 0..<600 {
            let input = random.markdownSoup(length: random.next(below: 3_000))
            await check(input, "fragments case \(index)")
        }
    }

    @Test func randomBytes() async {
        var random = SeededRandom(seed: 42)
        for index in 0..<200 {
            let bytes = (0..<random.next(below: 4_096)).map { _ in UInt8(truncatingIfNeeded: random.next()) }
            await check(UTF8Text.decode(bytes).text, "bytes case \(index)")
        }
    }

    @Test func mutatedElementsFile() async throws {
        let original = Array(try Fixtures.text("elements.md"))
        var random = SeededRandom(seed: 7)
        for index in 0..<300 {
            var text = original
            for _ in 0..<(1 + random.next(below: 40)) where !text.isEmpty {
                let position = random.next(below: text.count)
                switch random.next(below: 3) {
                case 0: text.remove(at: position)
                case 1: text.insert(random.markdownCharacter(), at: position)
                default:
                    let end = min(text.count, position + random.next(below: 200))
                    text.insert(contentsOf: text[position..<end], at: position)
                }
            }
            await check(String(text), "mutation case \(index)")
        }
    }

    // MARK: Truncated files

    @Test(arguments: Fixtures.files.filter { $0.hasSuffix(".md") })
    func truncatedFixture(_ file: String) async throws {
        let text = Array(try Fixtures.text(file))
        let step = max(1, text.count / 400)
        for cut in stride(from: 0, through: text.count, by: step) {
            await check(String(text[..<cut]), "\(file) cut at \(cut)")
        }
    }

    // MARK: Pathological input

    /// Inputs that crashed or hung before roadmap 2.9, and similar ones.
    static let pathological: [(String, String)] = [
        ("1,000 nested quotes", String(repeating: ">", count: 1_000) + " x\n"),
        ("100,000 nested quotes", String(repeating: ">", count: 100_000) + " x\n"),
        ("quotes with spaces", String(repeating: "> ", count: 5_000) + "x\n"),
        ("1,000 nested lists", (0..<1_000).map { String(repeating: "  ", count: $0) + "- x" }.joined(separator: "\n")),
        ("3,000 nested lists", (0..<3_000).map { String(repeating: "  ", count: $0) + "- x" }.joined(separator: "\n")),
        ("numbered lists", (0..<2_000).map { String(repeating: "   ", count: $0) + "1. x" }.joined(separator: "\n")),
        ("10,000 asterisks", String(repeating: "*", count: 10_000) + "x" + String(repeating: "*", count: 10_000)),
        ("100,000 underscores", String(repeating: "_", count: 100_000) + "x" + String(repeating: "_", count: 100_000)),
        ("alternating emphasis", String(repeating: "*a _b ", count: 20_000)),
        ("10,000 brackets", String(repeating: "[", count: 10_000) + "x" + String(repeating: "](u)", count: 10_000)),
        ("unclosed brackets", String(repeating: "[a](", count: 20_000)),
        ("long backtick runs", String(repeating: "`", count: 10_000) + " x " + String(repeating: "`", count: 9_999)),
        ("5,000-column table", "|" + String(repeating: " a |", count: 5_000) + "\n|" + String(repeating: "---|", count: 5_000) + "\n|" + String(repeating: " 1 |", count: 5_000) + "\n"),
        ("10,000-row table", "| a | b |\n|---|---|\n" + String(repeating: "| 1 | 2 |\n", count: 10_000)),
        ("1 MB line with links", String(repeating: "word https://a.com ", count: 55_000)),
        ("many links", String(repeating: "[a](b) ", count: 50_000)),
        ("list and quote mix", String(repeating: "> - ", count: 2_000) + "x\n"),
        ("deep HTML", String(repeating: "<div>", count: 10_000)),
        ("only newlines", String(repeating: "\n", count: 100_000)),
        ("only spaces", String(repeating: " ", count: 100_000)),
        ("NUL and control characters", String(repeating: "\u{0}\u{1}\u{7}\u{1B}\u{7F}", count: 2_000)),
        ("unclosed fence", "```\n" + String(repeating: "code\n", count: 20_000)),
        ("unclosed front matter", "---\n" + String(repeating: "key: value\n", count: 10_000)),
        ("www. everywhere", String(repeating: "www.", count: 50_000)),
        ("entities", String(repeating: "&amp;&#x1F600;&bogus;&", count: 10_000)),
        ("combining marks", "a" + String(repeating: "\u{0301}", count: 50_000)),
        ("headings", String(repeating: "# h\n", count: 20_000)),
        ("setext underline storm", String(repeating: "a\n===\n---\n", count: 10_000)),
    ]

    @Test(arguments: pathological.map(\.0))
    func pathologicalInput(_ name: String) async throws {
        let input = try #require(Self.pathological.first { $0.0 == name }?.1)
        await check(input, name)
    }

    // MARK: The guard itself

    @Test func deepInputsAreShownAsPlainText() async {
        for (name, input) in Self.pathological where NestingGuard.estimatedDepth(input) > NestingGuard.limit {
            let html = await HTMLRenderer.renderSafely(markdown: input).html
            #expect(html.hasPrefix(HTMLRenderer.tooDeeplyNestedNotice), "\(name) should fall back to plain text")
        }
    }

    @Test(arguments: [
        ("1,000 nested quotes", 1_000), ("10,000 asterisks", 10_000), ("3,000 nested lists", 3_000),
    ])
    func estimateCoversTheCrashCases(_ name: String, _ minimum: Int) throws {
        let input = try #require(Self.pathological.first { $0.0 == name }?.1)
        #expect(NestingGuard.estimatedDepth(input) >= minimum)
    }

    @Test(arguments: Fixtures.files.filter { $0.hasSuffix(".md") && !Fixtures.deliberatelyDeep.contains($0) })
    func realFilesAreNotFlagged(_ file: String) throws {
        let depth = NestingGuard.estimatedDepth(try Fixtures.text(file))
        #expect(depth < 50, "\(file) estimated \(depth) levels deep")
    }

    @Test func horizontalRulesAndBoldAreNotDeep() {
        #expect(NestingGuard.estimatedDepth(String(repeating: "-", count: 80) + "\n**bold** __x__\n") < 10)
    }
}

// MARK: - Helpers

extension Fixtures {
    static func text(_ relativePath: String) throws -> String {
        UTF8Text.decode(try Data(contentsOf: directory.appending(path: relativePath))).text
    }
}

/// SplitMix64: small, fast, and the same sequence for the same seed.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(below bound: Int) -> Int {
        bound <= 0 ? 0 : Int(next() % UInt64(bound))
    }

    /// Pieces that mean something to Markdown, plus ordinary text.
    private static let pieces: [String] = [
        "*", "**", "_", "__", "~", "~~", "`", "```", "~~~", "[", "]", "(", ")", "![", "<", ">", "> ",
        "#", "## ", "###### ", "-", "- ", "+ ", "* ", "1. ", "7) ", "- [ ] ", "- [x] ", "|", "|---|", ":-:",
        "---", "***", "===", "\\", "&", "&amp;", "&#", ";", "\"", "'", "!", "?", ".", ",", ":",
        "http://", "https://", "www.", ".com", "/", "@", "<div>", "</div>", "<script>", "<!--", "-->",
        "\n", "\n\n", "  \n", "    ", "\t", " ", "  ", "word", "x", "é", "日本", "🎉", "\u{0301}", "\r\n",
    ]

    mutating func markdownSoup(length: Int) -> String {
        var text = ""
        for _ in 0..<length { text += Self.pieces[next(below: Self.pieces.count)] }
        return text
    }

    mutating func markdownCharacter() -> Character {
        let piece = Self.pieces[next(below: Self.pieces.count)]
        return piece.first ?? " "
    }
}
