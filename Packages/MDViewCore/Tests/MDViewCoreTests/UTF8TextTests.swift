import Foundation
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
        #expect(result == DecodedText(text: "hi", hadInvalidBytes: false, hadByteOrderMark: true))
    }

    @Test func byteOrderMarkOnlyIsEmpty() {
        #expect(UTF8Text.decode([0xEF, 0xBB, 0xBF]) == DecodedText(text: "", hadInvalidBytes: false, hadByteOrderMark: true))
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

@Suite("UTF8Text.encode (spec 11.8)")
struct UTF8TextEncodeTests {
    @Test func textIsWrittenAsUTF8() {
        #expect(UTF8Text.encode("# Héllo ✓\n", byteOrderMark: false) == Array("# Héllo ✓\n".utf8))
    }

    @Test func emptyTextIsNoBytes() {
        #expect(UTF8Text.encode("", byteOrderMark: false).isEmpty)
    }

    @Test func byteOrderMarkIsPutBack() {
        #expect(UTF8Text.encode("hi", byteOrderMark: true) == [0xEF, 0xBB, 0xBF] + Array("hi".utf8))
    }

    @Test func lineEndingsAreKept() {
        let text = "a\r\nb\nc\rd\r\n"
        #expect(UTF8Text.encode(text, byteOrderMark: false) == Array("a\r\nb\nc\rd\r\n".utf8))
    }

    @Test func editedLinesKeepTheirNeighboursEndings() {
        // Typing "x" into a CRLF file changes only that character.
        let decoded = UTF8Text.decode(Array("one\r\ntwo\r\n".utf8))
        let edited = decoded.text.replacingOccurrences(of: "two", with: "twox")
        #expect(UTF8Text.encode(edited, byteOrderMark: decoded.hadByteOrderMark) == Array("one\r\ntwox\r\n".utf8))
    }

    /// Every fixture that decodes cleanly saves back to exactly its own
    /// bytes, and the ones that don't (Latin-1, UTF-16) are reported, so
    /// they can't be edited (spec 11.8, 11.10).
    @Test(arguments: Fixtures.files)
    func fixturesRoundTrip(_ relativePath: String) throws {
        let bytes = try [UInt8](Data(contentsOf: Fixtures.directory.appending(path: relativePath)))
        let decoded = UTF8Text.decode(bytes)
        if Self.notUTF8.contains(relativePath) {
            #expect(decoded.hadInvalidBytes)
        } else {
            #expect(!decoded.hadInvalidBytes)
            #expect(UTF8Text.encode(decoded.text, byteOrderMark: decoded.hadByteOrderMark) == bytes)
        }
    }

    @Test func fixturesCoverByteOrderMarkAndCRLF() throws {
        let bom = try Data(contentsOf: Fixtures.directory.appending(path: "edge/bom.md"))
        let crlf = try Data(contentsOf: Fixtures.directory.appending(path: "edge/crlf.md"))
        #expect(UTF8Text.decode(bom).hadByteOrderMark)
        #expect(UTF8Text.decode(crlf).text.utf8.contains(0x0D))
    }

    static let notUTF8: Set<String> = ["edge/latin1.md", "edge/utf16.md"]
}
