/// Colours code for a code block (spec section 7, ADR 0004).
///
/// One pass, left to right, over the code's Unicode scalars. At each
/// position it checks, in order: block comment, line comment, string,
/// number, word (keyword or not), anything else. Every branch moves
/// forward at least one scalar, so it always finishes (spec 7.6). All text
/// is HTML-escaped; tokens are wrapped in `<span class="tok-…">`.
public enum Highlighter {
    public enum Kind: String, Sendable, CaseIterable {
        case keyword, string, comment, number
    }

    public static func highlight(_ code: String, rules: LanguageRules) -> String {
        var scanner = Scanner(code: code, rules: rules)
        return scanner.run()
    }
}

private struct Scanner {
    let text: [Unicode.Scalar]
    let rules: LanguageRules
    let lineComments: [[Unicode.Scalar]]
    let blockComments: [(open: [Unicode.Scalar], close: [Unicode.Scalar], nests: Bool)]
    let strings: [(open: [Unicode.Scalar], close: [Unicode.Scalar], escape: Unicode.Scalar?, spansLines: Bool)]

    var index = 0
    var output = ""
    /// Plain text not yet written, so neighbouring plain runs are escaped
    /// and written once.
    var plainStart = 0

    init(code: String, rules: LanguageRules) {
        text = Array(code.unicodeScalars)
        self.rules = rules
        lineComments = rules.lineComments.map { Array($0.unicodeScalars) }
        blockComments = rules.blockComments.map { (Array($0.open.unicodeScalars), Array($0.close.unicodeScalars), $0.nests) }
        strings = rules.strings.map {
            (Array($0.open.unicodeScalars), Array($0.close.unicodeScalars), $0.escape?.unicodeScalars.first, $0.spansLines)
        }
        output.reserveCapacity(code.utf8.count + code.utf8.count / 4)
    }

    mutating func run() -> String {
        while index < text.count {
            let start = index
            if let kind = scanToken() {
                emit(kind, from: start)
            } else if isWordStart(text[index]) {
                let wordStart = index
                while index < text.count, isWordCharacter(text[index]) { index += 1 }
                let word = String(String.UnicodeScalarView(text[wordStart..<index]))
                if rules.keywords.contains(word) { emit(.keyword, from: wordStart) }
            } else {
                index += 1
            }
            // Every branch moves forward; this only guards against a future
            // mistake turning into a hang (spec 7.6).
            assert(index > start, "the scanner must always move forward")
            if index == start { index += 1 }
        }
        flushPlain(upTo: text.count)
        return output
    }

    /// A comment, string or number starting at `index`; moves past it.
    private mutating func scanToken() -> Highlighter.Kind? {
        for comment in blockComments where matches(comment.open, at: index) {
            index += comment.open.count
            var depth = 1
            while index < text.count {
                if matches(comment.close, at: index) {
                    index += comment.close.count
                    depth -= 1
                    if depth == 0 { break }
                } else if comment.nests, matches(comment.open, at: index) {
                    index += comment.open.count
                    depth += 1
                } else {
                    index += 1
                }
            }
            return .comment
        }
        for opener in lineComments where matches(opener, at: index) {
            if rules.lineCommentNeedsSpaceBefore, index > 0, !canPrecedeLineComment(text[index - 1]) { continue }
            while index < text.count, !isNewline(text[index]) { index += 1 }
            return .comment
        }
        for style in strings where matches(style.open, at: index) {
            index += style.open.count
            while index < text.count {
                if let escape = style.escape, text[index] == escape {
                    index += min(2, text.count - index)
                } else if matches(style.close, at: index) {
                    index += style.close.count
                    break
                } else if !style.spansLines, isNewline(text[index]) {
                    break  // unclosed: stop at the end of the line
                } else {
                    index += 1
                }
            }
            return .string
        }
        if rules.highlightsNumbers, isNumberStart(at: index) {
            scanNumber()
            return .number
        }
        return nil
    }

    // MARK: Numbers

    /// A digit (or `.` then a digit) that isn't part of a word, like the
    /// `1` in `x1`.
    private func isNumberStart(at i: Int) -> Bool {
        if i > 0, isWordCharacter(text[i - 1]) { return false }
        if isDigit(text[i]) { return true }
        return text[i] == "." && i + 1 < text.count && isDigit(text[i + 1]) && (i == 0 || !isDigit(text[i - 1]))
    }

    /// Decimal, `0x` / `0o` / `0b`, `_` separators, a fraction, an exponent,
    /// and a short suffix (`10u`, `1.5f`, `3n`).
    private mutating func scanNumber() {
        if text[index] == "0", index + 1 < text.count, "xXoObB".unicodeScalars.contains(text[index + 1]) {
            index += 2
            while index < text.count, isHexDigit(text[index]) || text[index] == "_" { index += 1 }
            return
        }
        while index < text.count, isDigit(text[index]) || text[index] == "_" { index += 1 }
        if index + 1 < text.count, text[index] == ".", isDigit(text[index + 1]) {
            index += 1
            while index < text.count, isDigit(text[index]) || text[index] == "_" { index += 1 }
        }
        if index < text.count, text[index] == "e" || text[index] == "E" {
            var next = index + 1
            if next < text.count, text[next] == "+" || text[next] == "-" { next += 1 }
            if next < text.count, isDigit(text[next]) {
                index = next
                while index < text.count, isDigit(text[index]) { index += 1 }
            }
        }
        // A short letter suffix, only if the word ends there (so `10px` is
        // coloured but `123abc` isn't extended without end).
        var suffixEnd = index
        while suffixEnd < text.count, suffixEnd - index < 3, text[suffixEnd].properties.isAlphabetic { suffixEnd += 1 }
        if suffixEnd == text.count || !isWordCharacter(text[suffixEnd]) { index = suffixEnd }
    }

    // MARK: Output

    private mutating func emit(_ kind: Highlighter.Kind, from start: Int) {
        flushPlain(upTo: start)
        output += "<span class=\"tok-\(kind.rawValue)\">"
        output += HTMLEscaping.escape(String(String.UnicodeScalarView(text[start..<index])))
        output += "</span>"
        plainStart = index
    }

    private mutating func flushPlain(upTo end: Int) {
        guard plainStart < end else { return }
        output += HTMLEscaping.escape(String(String.UnicodeScalarView(text[plainStart..<end])))
        plainStart = end
    }

    // MARK: Characters

    private func matches(_ pattern: [Unicode.Scalar], at i: Int) -> Bool {
        guard !pattern.isEmpty, i + pattern.count <= text.count else { return false }
        for (offset, scalar) in pattern.enumerated() where text[i + offset] != scalar { return false }
        return true
    }

    private func isWordStart(_ c: Unicode.Scalar) -> Bool {
        c.properties.isAlphabetic || c == "_" || rules.wordCharacters.contains(Character(c)) && !isDigit(c)
    }

    private func isWordCharacter(_ c: Unicode.Scalar) -> Bool {
        c.properties.isAlphabetic || isDigit(c) || c == "_" || rules.wordCharacters.contains(Character(c))
    }

    private func isDigit(_ c: Unicode.Scalar) -> Bool { ("0"..."9").contains(c) }
    private func isHexDigit(_ c: Unicode.Scalar) -> Bool { isDigit(c) || ("a"..."f").contains(c) || ("A"..."F").contains(c) }
    private func isNewline(_ c: Unicode.Scalar) -> Bool { c == "\n" || c == "\r" }
    /// Where a shell-style `#` comment can start: after a space, a line
    /// break, or `;`, `|`, `&`, `(`.
    private func canPrecedeLineComment(_ c: Unicode.Scalar) -> Bool {
        c == " " || c == "\t" || isNewline(c) || c == ";" || c == "|" || c == "&" || c == "("
    }
}
