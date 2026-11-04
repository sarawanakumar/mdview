import Testing
@testable import MDViewCore

@Suite("UTF8Text.decode")
struct UTF8TextTests {
    @Test func validTextIsUnchanged() {
        let result = UTF8Text.decode(Array("# Héllo ✓\n".utf8))
        #expect(result == DecodedText(text: "# Héllo ✓\n", hadInvalidBytes: false))
    }

    @Test func emptyFileIsEmptyText() {
        #expect(UTF8Text.decode([UInt8]()) == DecodedText(text: "", hadInvalidBytes: false))
    }

    @Test func byteOrderMarkIsDropped() {
        let result = UTF8Text.decode([0xEF, 0xBB, 0xBF] + Array("hi".utf8))
        #expect(result == DecodedText(text: "hi", hadInvalidBytes: false))
    }

    @Test func byteOrderMarkOnlyIsEmpty() {
        #expect(UTF8Text.decode([0xEF, 0xBB, 0xBF]) == DecodedText(text: "", hadInvalidBytes: false))
    }

    @Test func invalidBytesAreReplacedAndReported() {
        // "a", a lone 0xFF, "b", then a truncated two-byte sequence.
        let result = UTF8Text.decode([0x61, 0xFF, 0x62, 0xC3])
        #expect(result.hadInvalidBytes)
        #expect(result.text == "a\u{FFFD}b\u{FFFD}")
    }

    @Test func latin1TextIsReportedAsInvalid() {
        // "café" saved as Latin-1: é is the single byte 0xE9.
        let result = UTF8Text.decode([0x63, 0x61, 0x66, 0xE9])
        #expect(result.hadInvalidBytes)
        #expect(result.text.hasPrefix("caf"))
    }
}
