/// How one language's code is coloured (ADR 0004): which words are
/// keywords and how comments and strings are written. Numbers are found
/// the same way for every language.
public struct LanguageRules: Sendable {
    public struct BlockComment: Sendable {
        public var open: String
        public var close: String
        /// Swift allows `/* /* */ */`; most languages don't.
        public var nests: Bool

        public init(open: String, close: String, nests: Bool = false) {
            self.open = open
            self.close = close
            self.nests = nests
        }
    }

    public struct StringStyle: Sendable {
        public var open: String
        public var close: String
        /// The character that escapes the next one (`\` in most languages).
        public var escape: Character?
        /// Whether the string can run over several lines. If not, an
        /// unclosed string stops at the end of its line.
        public var spansLines: Bool
        /// Only a string right after this character (spaces between are
        /// fine). HTML uses `=`, so attribute values are strings but an
        /// apostrophe in text isn't.
        public var onlyAfter: Character?

        public init(
            open: String, close: String? = nil, escape: Character? = "\\",
            spansLines: Bool = false, onlyAfter: Character? = nil
        ) {
            self.open = open
            self.close = close ?? open
            self.escape = escape
            self.spansLines = spansLines
            self.onlyAfter = onlyAfter
        }
    }

    public var keywords: Set<String>
    public var lineComments: [String]
    public var blockComments: [BlockComment]
    public var strings: [StringStyle]
    /// Characters besides letters, digits and `_` that can be part of a
    /// word (`$` in JavaScript, `-` in CSS and shell).
    public var wordCharacters: Set<Character>
    /// A line comment only starts at the beginning of a word, as `#` in
    /// shell (`$#` and `a#b` aren't comments).
    public var lineCommentNeedsSpaceBefore: Bool
    public var highlightsNumbers: Bool
    /// HTML and XML: a word right after `<` or `</` is a keyword (the tag
    /// name), whatever `keywords` says.
    public var tagNamesAreKeywords: Bool

    public init(
        keywords: Set<String> = [],
        lineComments: [String] = [],
        blockComments: [BlockComment] = [],
        strings: [StringStyle] = [],
        wordCharacters: Set<Character> = [],
        lineCommentNeedsSpaceBefore: Bool = false,
        highlightsNumbers: Bool = true,
        tagNamesAreKeywords: Bool = false
    ) {
        self.keywords = keywords
        self.lineComments = lineComments
        self.blockComments = blockComments
        // Longest opener first, so `"""` wins over `"`.
        self.strings = strings.sorted { $0.open.count > $1.open.count }
        self.wordCharacters = wordCharacters
        self.lineCommentNeedsSpaceBefore = lineCommentNeedsSpaceBefore
        self.highlightsNumbers = highlightsNumbers
        self.tagNamesAreKeywords = tagNamesAreKeywords
    }
}
