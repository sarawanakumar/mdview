/// The languages mdview colours (spec 7.1), one `LanguageRules` table each.
/// Aim: clearly readable, not editor-grade (ADR 0004). Roadmap 6.4 maps
/// code fence tags (`swift`, `py`, `ts`, …) to these.
public enum Languages {
    /// The rules for a code fence's language tag (already lowercased), or
    /// nil for an unknown tag, which stays plain (spec 7.4). Spec 7.1's tags,
    /// plus a few close relatives that use the same rules.
    public static func rules(forTag tag: String) -> LanguageRules? {
        switch tag.lowercased() {
        case "swift": swift
        case "python", "py": python
        case "javascript", "js", "jsx", "mjs", "cjs": javaScript
        case "typescript", "ts", "tsx": typeScript
        case "sh", "bash", "zsh", "shell": shell
        case "json", "jsonc": json
        case "yaml", "yml": yaml
        case "html", "htm", "xml", "svg": html
        case "css": css
        default: nil
        }
    }

    // MARK: Swift

    public static let swift = LanguageRules(
        keywords: [
            // Declarations
            "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init",
            "inout", "internal", "let", "open", "operator", "precedencegroup", "private", "protocol", "public",
            "rethrows", "static", "struct", "subscript", "typealias", "var", "actor", "macro", "package",
            // Statements
            "break", "case", "catch", "continue", "default", "defer", "do", "else", "fallthrough", "for",
            "guard", "if", "in", "repeat", "return", "throw", "switch", "where", "while",
            // Expressions and types
            "as", "Any", "false", "is", "nil", "self", "Self", "super", "throws", "true", "try", "await", "async",
            "some", "any",
            // Common contextual keywords
            "mutating", "nonmutating", "lazy", "weak", "unowned", "override", "final", "required", "convenience",
            "dynamic", "optional", "indirect", "get", "set", "willSet", "didSet", "nonisolated", "isolated",
            "consuming", "borrowing", "sending",
        ],
        lineComments: ["//"],
        blockComments: [.init(open: "/*", close: "*/", nests: true)],
        strings: [
            .init(open: "\"\"\"", spansLines: true),
            .init(open: "\""),
            .init(open: "#\"\"\"", close: "\"\"\"#", escape: nil, spansLines: true),
            .init(open: "#\"", close: "\"#", escape: nil),
        ]
    )

    // MARK: Python

    public static let python = LanguageRules(
        keywords: [
            "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class", "continue",
            "def", "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in",
            "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield",
            "match", "case", "type",
        ],
        lineComments: ["#"],
        strings: [
            .init(open: "\"\"\"", spansLines: true),
            .init(open: "'''", spansLines: true),
            .init(open: "\""),
            .init(open: "'"),
        ]
    )

    // MARK: JavaScript and TypeScript

    private static let javaScriptKeywords: Set<String> = [
        "async", "await", "break", "case", "catch", "class", "const", "continue", "debugger", "default",
        "delete", "do", "else", "export", "extends", "false", "finally", "for", "from", "function", "get",
        "if", "import", "in", "instanceof", "let", "new", "null", "of", "return", "set", "static", "super",
        "switch", "this", "throw", "true", "try", "typeof", "undefined", "var", "void", "while", "with", "yield",
    ]

    private static let typeScriptExtras: Set<String> = [
        "abstract", "any", "as", "asserts", "bigint", "boolean", "declare", "enum", "implements", "infer",
        "interface", "is", "keyof", "module", "namespace", "never", "number", "object", "override", "private",
        "protected", "public", "readonly", "satisfies", "string", "symbol", "type", "unique", "unknown",
    ]

    private static let javaScriptStrings: [LanguageRules.StringStyle] = [
        .init(open: "`", spansLines: true),
        .init(open: "\""),
        .init(open: "'"),
    ]

    public static let javaScript = LanguageRules(
        keywords: javaScriptKeywords,
        lineComments: ["//"],
        blockComments: [.init(open: "/*", close: "*/")],
        strings: javaScriptStrings,
        wordCharacters: ["$"]
    )

    public static let typeScript = LanguageRules(
        keywords: javaScriptKeywords.union(typeScriptExtras),
        lineComments: ["//"],
        blockComments: [.init(open: "/*", close: "*/")],
        strings: javaScriptStrings,
        wordCharacters: ["$"]
    )

    // MARK: Shell (sh, bash, zsh)

    public static let shell = LanguageRules(
        keywords: [
            "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do", "done", "in",
            "function", "select", "time", "return", "exit", "break", "continue",
            // Common built-ins
            "local", "export", "readonly", "declare", "typeset", "unset", "shift", "source", "eval", "exec",
            "set", "trap", "alias", "echo", "printf", "read", "cd", "test",
        ],
        lineComments: ["#"],
        strings: [
            .init(open: "\"", spansLines: true),
            .init(open: "'", escape: nil, spansLines: true),
        ],
        wordCharacters: ["-"],
        lineCommentNeedsSpaceBefore: true
    )

    // MARK: JSON

    /// Comments aren't JSON, but many config files have them, so they're
    /// coloured rather than shown as errors.
    public static let json = LanguageRules(
        keywords: ["true", "false", "null"],
        lineComments: ["//"],
        blockComments: [.init(open: "/*", close: "*/")],
        strings: [.init(open: "\"")]
    )

    // MARK: YAML

    public static let yaml = LanguageRules(
        keywords: ["true", "false", "null", "True", "False", "Null", "TRUE", "FALSE", "NULL", "yes", "no", "on", "off"],
        lineComments: ["#"],
        strings: [
            .init(open: "\""),
            .init(open: "'", escape: nil),
        ],
        wordCharacters: ["-"],
        lineCommentNeedsSpaceBefore: true
    )

    // MARK: HTML

    /// Tag names, attribute values and comments. Text between tags stays
    /// plain: numbers aren't coloured, and quotes only count after `=`.
    public static let html = LanguageRules(
        blockComments: [.init(open: "<!--", close: "-->")],
        strings: [
            .init(open: "\"", escape: nil, spansLines: true, onlyAfter: "="),
            .init(open: "'", escape: nil, spansLines: true, onlyAfter: "="),
        ],
        wordCharacters: ["-"],
        highlightsNumbers: false,
        tagNamesAreKeywords: true
    )

    // MARK: CSS

    public static let css = LanguageRules(
        keywords: [
            "@media", "@import", "@supports", "@keyframes", "@font-face", "@layer", "@container", "@page",
            "@charset", "@namespace", "@property", "@scope",
            "important", "inherit", "initial", "unset", "revert", "auto", "none",
        ],
        blockComments: [.init(open: "/*", close: "*/")],
        strings: [
            .init(open: "\""),
            .init(open: "'"),
        ],
        // `-` for property names and `@` for at-rules; `#` so hex colours
        // and id selectors stay whole rather than partly coloured.
        wordCharacters: ["-", "@", "#"]
    )
}
