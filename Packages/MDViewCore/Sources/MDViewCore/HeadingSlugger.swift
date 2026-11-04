/// Turns heading text into GitHub-style anchor names, so links such as
/// `#installation` work the same as on GitHub (spec 4.3).
///
/// The rules, matching GitHub's `github-slugger`:
/// - lowercase the text;
/// - keep letters, marks, numbers, `-` and `_` (in any script);
/// - turn each space into `-` (runs are not merged);
/// - drop everything else (punctuation, symbols, emoji);
/// - a repeated name gets `-1`, `-2`, … added, skipping any that already
///   exist.
///
/// One slugger per document, so numbering restarts for each file.
struct HeadingSlugger {
    /// How many times each base name has been handed out, plus every name
    /// already in use.
    private var used: [String: Int] = [:]

    mutating func slug(for text: String) -> String {
        let base = Self.baseSlug(text)
        var result = base
        if let count = used[base] {
            var next = count
            repeat {
                next += 1
                result = "\(base)-\(next)"
            } while used[result] != nil
            used[base] = next
        }
        used[result] = 0
        return result
    }

    static func baseSlug(_ text: String) -> String {
        var slug = ""
        for scalar in text.lowercased().unicodeScalars {
            let properties = scalar.properties
            if scalar == " " {
                slug.append("-")
            } else if scalar == "-" || scalar == "_"
                        || properties.isAlphabetic
                        || properties.generalCategory.isMark
                        || properties.generalCategory.isNumber {
                slug.unicodeScalars.append(scalar)
            }
        }
        return slug
    }
}

private extension Unicode.GeneralCategory {
    var isMark: Bool {
        self == .nonspacingMark || self == .spacingMark || self == .enclosingMark
    }

    var isNumber: Bool {
        self == .decimalNumber || self == .letterNumber || self == .otherNumber
    }
}
