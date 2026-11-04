/// Finds bare web addresses in plain text, as GitHub does (spec 2.14).
///
/// Follows GitHub-flavored Markdown's "extended autolinks":
/// - `http://`, `https://` or `www.`, at the start of the text or after a
///   space or one of `*`, `_`, `~`, `(`;
/// - then a domain: characters other than spaces and punctuation, plus `-`,
///   `_` and `.`, with at least one `.` and no `_` in its last two parts;
/// - then anything up to a space or `<`;
/// - minus trailing punctuation (`? ! . , : * _ ~ ' "`), an unmatched `)`,
///   and a trailing entity-like `&name;`.
/// `www.` links get `http://` in front. Email addresses aren't linked.
enum Autolinker {
    enum Segment: Equatable {
        case text(Substring)
        case link(text: Substring, url: String)
    }

    static func segments(in text: String) -> [Segment] {
        guard mightContainLink(text) else { return [.text(text[...])] }
        var segments: [Segment] = []
        var plainStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            if canStartLink(in: text, at: index), let (end, url) = link(in: text, at: index) {
                if plainStart < index { segments.append(.text(text[plainStart..<index])) }
                segments.append(.link(text: text[index..<end], url: url))
                index = end
                plainStart = end
            } else {
                index = text.index(after: index)
            }
        }
        if plainStart < text.endIndex { segments.append(.text(text[plainStart...])) }
        return segments
    }

    // MARK: Pieces

    /// Fast check on the raw bytes: no "ht" or "ww" (any case) means no link.
    /// Most text has none, and this skips the slower character-by-character
    /// scan.
    private static func mightContainLink(_ text: String) -> Bool {
        var previous: UInt8 = 0
        for byte in text.utf8 {
            let lower = byte | 0x20
            if (previous == UInt8(ascii: "h") && lower == UInt8(ascii: "t"))
                || (previous == UInt8(ascii: "w") && lower == UInt8(ascii: "w")) {
                return true
            }
            previous = lower
        }
        return false
    }

    private static func canStartLink(in text: String, at index: String.Index) -> Bool {
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        return previous.isWhitespace || "*_~(".contains(previous)
    }

    /// The end of a link starting at `index`, and its URL, or nil.
    private static func link(in text: String, at index: String.Index) -> (String.Index, String)? {
        // Cheap check first: this runs at every position in the text.
        let first = text[index]
        guard first == "h" || first == "H" || first == "w" || first == "W" else { return nil }
        let start = text[index...].prefix(8).lowercased()
        let prefix: String
        if start.hasPrefix("https://") {
            prefix = String(text[index...].prefix(8))
        } else if start.hasPrefix("http://") {
            prefix = String(text[index...].prefix(7))
        } else if start.hasPrefix("www.") {
            prefix = ""
        } else {
            return nil
        }

        let domainStart = text.index(index, offsetBy: prefix.count)
        guard let domainEnd = validDomainEnd(in: text, from: domainStart) else { return nil }

        // Everything up to a space or "<", then trimmed.
        var end = text[domainEnd...].firstIndex(where: { $0.isWhitespace || $0 == "<" }) ?? text.endIndex
        end = trimmedEnd(of: text[index..<end])
        guard end > domainStart else { return nil }

        let linkText = text[index..<end]
        let url = prefix.isEmpty ? "http://" + linkText : String(linkText)
        return (end, url)
    }

    /// Where a valid domain starting at `start` ends, or nil if there isn't
    /// one.
    private static func validDomainEnd(in text: String, from start: String.Index) -> String.Index? {
        var index = start
        var parts: [Substring] = []
        var partStart = start
        while index < text.endIndex {
            let character = text[index]
            if character == "." {
                parts.append(text[partStart..<index])
                partStart = text.index(after: index)
            } else if !(character == "-" || character == "_" || isHostCharacter(character)) {
                break
            }
            index = text.index(after: index)
        }
        parts.append(text[partStart..<index])

        // A trailing "." belongs to the sentence, not the domain.
        while parts.count > 1, parts.last?.isEmpty == true { parts.removeLast() }
        guard parts.count >= 2, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        guard !parts.suffix(2).contains(where: { $0.contains("_") }) else { return nil }
        return index
    }

    private static func isHostCharacter(_ character: Character) -> Bool {
        !character.isWhitespace && !character.isPunctuation && !character.isSymbol
    }

    /// Drops trailing punctuation, unmatched ")" and an entity-like "&x;".
    private static func trimmedEnd(of link: Substring) -> String.Index {
        var link = link
        while let last = link.last {
            if "?!.,:*_~'\"".contains(last) {
                link = link.dropLast()
            } else if last == ")" {
                let opens = link.filter { $0 == "(" }.count
                let closes = link.filter { $0 == ")" }.count
                guard closes > opens else { break }
                link = link.dropLast()
            } else if last == ";", let ampersand = link.lastIndex(of: "&"),
                      link[link.index(after: ampersand)..<link.index(before: link.endIndex)]
                          .allSatisfy({ $0.isLetter || $0.isNumber }),
                      link.index(after: ampersand) < link.index(before: link.endIndex) {
                link = link[..<ampersand]
            } else {
                break
            }
        }
        return link.endIndex
    }
}
