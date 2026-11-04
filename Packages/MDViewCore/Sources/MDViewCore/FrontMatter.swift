/// Removes a YAML front matter block from the start of a file (spec 2.13).
///
/// Front matter is a `---` line on the very first line, up to the next line
/// that is `---` or `...`. If there's no closing line, the opening `---` is
/// left alone (it's then an ordinary horizontal rule). A `---` anywhere
/// else is never touched.
public enum FrontMatter {
    public static func strip(_ text: String) -> String {
        var (line, next) = nextLine(in: text, from: text.startIndex)
        guard isFence(line, allowDots: false) else { return text }
        while next < text.endIndex {
            (line, next) = nextLine(in: text, from: next)
            if isFence(line, allowDots: true) {
                return String(text[next...])
            }
        }
        return text
    }

    /// The line starting at `start` (without its line ending) and where the
    /// following line starts. Handles `\n`, `\r\n` and `\r` (Swift treats
    /// `\r\n` as one character).
    private static func nextLine(in text: String, from start: String.Index) -> (Substring, String.Index) {
        guard let end = text[start...].firstIndex(where: \.isNewline) else {
            return (text[start...], text.endIndex)
        }
        return (text[start..<end], text.index(after: end))
    }

    /// `---` (or `...` when closing), ignoring trailing spaces and tabs.
    private static func isFence(_ line: Substring, allowDots: Bool) -> Bool {
        var trimmed = line
        while let last = trimmed.last, last == " " || last == "\t" {
            trimmed = trimmed.dropLast()
        }
        return trimmed == "---" || (allowDots && trimmed == "...")
    }
}
