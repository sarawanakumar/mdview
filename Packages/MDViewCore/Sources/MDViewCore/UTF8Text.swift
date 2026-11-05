/// Turns a file's bytes into text (spec 10.1, 10.2), and edited text back
/// into bytes for saving (spec 11.8, ADR 0008).
public struct DecodedText: Equatable, Sendable {
    /// The file's text. Invalid UTF-8 sequences are replaced with U+FFFD.
    public let text: String
    /// True when some bytes weren't valid UTF-8 and had to be replaced.
    /// Such a file can't be saved back faithfully, so it can't be edited
    /// (spec 11.10).
    public let hadInvalidBytes: Bool
    /// True when the file started with a UTF-8 byte order mark, which
    /// `text` leaves out. Saving puts it back.
    public let hadByteOrderMark: Bool

    public init(text: String, hadInvalidBytes: Bool, hadByteOrderMark: Bool = false) {
        self.text = text
        self.hadInvalidBytes = hadInvalidBytes
        self.hadByteOrderMark = hadByteOrderMark
    }
}

public enum UTF8Text {
    private static let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]

    /// Decodes bytes as UTF-8, dropping a leading byte order mark. Never
    /// fails: bad bytes become U+FFFD and are reported in the result.
    public static func decode<Bytes: Collection<UInt8>>(_ bytes: Bytes) -> DecodedText {
        let hasMark = bytes.starts(with: byteOrderMark)
        let body = hasMark ? bytes.dropFirst(byteOrderMark.count) : bytes[...]
        if let text = String(validating: body, as: UTF8.self) {
            return DecodedText(text: text, hadInvalidBytes: false, hadByteOrderMark: hasMark)
        }
        return DecodedText(text: String(decoding: body, as: UTF8.self), hadInvalidBytes: true, hadByteOrderMark: hasMark)
    }

    /// The bytes to save for `text`: UTF-8, after a byte order mark if the
    /// file had one. Line endings are written exactly as they are in the
    /// text. For a file that decoded cleanly, `encode(decode(b).text,
    /// byteOrderMark: decode(b).hadByteOrderMark)` gives back `b`.
    public static func encode(_ text: String, byteOrderMark: Bool) -> [UInt8] {
        (byteOrderMark ? Self.byteOrderMark : []) + Array(text.utf8)
    }
}
