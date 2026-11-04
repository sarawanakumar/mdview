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
    /// following line starts. Handles `\n`, `\r\n` and `\r`. Searches the
    /// raw bytes: much faster than going character by character.
    private static func nextLine(in text: String, from start: String.Index) -> (Substring, String.Index) {
        let bytes = text.utf8
        guard let end = bytes[start...].firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) else {
            return (text[start...], text.endIndex)
        }
        var next = bytes.index(after: end)
        if bytes[end] == 0x0D, next < bytes.endIndex, bytes[next] == 0x0A {
            next = bytes.index(after: next)
        }
        return (text[start..<end], next)
    }

    /// `---` (or `...` when closing), ignoring trailing spaces and tabs.
    private static func isFence(_ line: Substring, allowDots: Bool) -> Bool {
        // A fence is three characters plus a little trailing space. Checking
        // the length first keeps very long lines fast: trimming them one
        // character at a time took 17 s for a line of 100,000 spaces.
        guard line.utf8.count <= 64 else { return false }
        var trimmed = line
        while let last = trimmed.last, last == " " || last == "\t" {
            trimmed = trimmed.dropLast()
        }
        return trimmed == "---" || (allowDots && trimmed == "...")
    }
}
