/// Turns a file's bytes into text (spec 10.1, 10.2).
public struct DecodedText: Equatable, Sendable {
    /// The file's text. Invalid UTF-8 sequences are replaced with U+FFFD.
    public let text: String
    /// True when some bytes weren't valid UTF-8 and had to be replaced.
    public let hadInvalidBytes: Bool

    public init(text: String, hadInvalidBytes: Bool) {
        self.text = text
        self.hadInvalidBytes = hadInvalidBytes
    }
}

public enum UTF8Text {
    private static let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]

    /// Decodes bytes as UTF-8, dropping a leading byte order mark. Never
    /// fails: bad bytes become U+FFFD and are reported in the result.
    public static func decode<Bytes: Collection<UInt8>>(_ bytes: Bytes) -> DecodedText {
        let body = bytes.starts(with: byteOrderMark) ? bytes.dropFirst(byteOrderMark.count) : bytes[...]
        if let text = String(validating: body, as: UTF8.self) {
            return DecodedText(text: text, hadInvalidBytes: false)
        }
        return DecodedText(text: String(decoding: body, as: UTF8.self), hadInvalidBytes: true)
    }
}
