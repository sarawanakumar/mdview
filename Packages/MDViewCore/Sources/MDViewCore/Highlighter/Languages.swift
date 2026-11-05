/// The languages mdview colours (spec 7.1), one `LanguageRules` table each.
/// Aim: clearly readable, not editor-grade (ADR 0004). Roadmap 6.4 maps
/// code fence tags (`swift`, `py`, `ts`, …) to these.
public enum Languages {
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
}
