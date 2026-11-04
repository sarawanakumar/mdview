/// Spec 10.4: any input renders something and never crashes or hangs.
///
/// swift-markdown handles nesting (quotes in quotes, lists in lists,
/// emphasis in emphasis) by recursion, so very deep nesting overflows the
/// stack. On a 512 KB stack (what Swift tasks get) about 1,000 levels
/// crash; on the 64 MB stack mdview renders with, 20,000 are fine and
/// 80,000 crash (roadmap 2.9).
///
/// This makes a quick, deliberately generous estimate of the deepest
/// nesting from the raw bytes. Files nested deeper than `limit` are shown
/// as plain text instead. Real documents are nested a handful of levels.
public enum NestingGuard {
    /// Far above any real document, far below what the 64 MB stack takes.
    public static let limit = 1_000

    public static func isTooDeep(_ text: String) -> Bool {
        estimatedDepth(text) > limit
    }

    /// The larger of:
    /// - per line, the block nesting at its start: each `>` and each list
    ///   marker (`-`, `*`, `+`, or digits then `.` or `)`, then a space)
    ///   counts one, plus one per two columns of indentation;
    /// - the longest run of `*`, `_` or `~` (emphasis nests by these).
    static func estimatedDepth(_ text: String) -> Int {
        var deepest = 0
        var lineDepth = 0
        var indent = 0
        var atLineStart = true          // still in the line's leading markers
        var pendingDigits = false
        var run = 0
        var runByte: UInt8 = 0
        var previous: UInt8 = 0

        for byte in text.utf8 {
            // Runs of emphasis characters, anywhere.
            if byte == UInt8(ascii: "*") || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "~") {
                run = byte == runByte ? run + 1 : 1
                runByte = byte
                deepest = max(deepest, run)
            } else {
                runByte = 0
            }

            if byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r") {
                deepest = max(deepest, lineDepth + indent / 2)
                lineDepth = 0; indent = 0; atLineStart = true; pendingDigits = false
                previous = byte
                continue
            }
            guard atLineStart else { previous = byte; continue }

            switch byte {
            case UInt8(ascii: " "):
                // A marker only counts when followed by a space.
                if previous == UInt8(ascii: "-") || previous == UInt8(ascii: "*") || previous == UInt8(ascii: "+")
                    || (pendingDigits && (previous == UInt8(ascii: ".") || previous == UInt8(ascii: ")"))) {
                    lineDepth += 1
                } else {
                    indent += 1
                }
                pendingDigits = false
            case UInt8(ascii: "\t"):
                indent += 4
            case UInt8(ascii: ">"):
                lineDepth += 1
            case UInt8(ascii: "-"), UInt8(ascii: "*"), UInt8(ascii: "+"), UInt8(ascii: "."), UInt8(ascii: ")"):
                break
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                pendingDigits = true
            default:
                atLineStart = false
            }
            previous = byte
        }
        return max(deepest, lineDepth + indent / 2)
    }
}
