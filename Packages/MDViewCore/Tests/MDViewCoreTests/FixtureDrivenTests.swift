import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MDViewCore

/// Roadmap 3.6: `fixtures/images.md` and `fixtures/links.md` checked end to
/// end, the way the app treats them.
@Suite("images.md and links.md (sections 3, 4)")
struct FixtureDrivenTests {
    static let imagesFile = Fixtures.directory.appending(path: "images.md")
    static let linksFile = Fixtures.directory.appending(path: "links.md")

    /// Like the app's locator with the fixtures folder granted: an existing
    /// image file next to the document.
    static let grantedLocator: ImageLocator = { source in
        guard let file = LocalReferences.resolve(source, relativeTo: imagesFile),
              let type = UTType(filenameExtension: file.pathExtension), type.conforms(to: .image),
              FileManager.default.fileExists(atPath: file.path) else { return nil }
        return "mdview-file://document" + file.path(percentEncoded: true)
    }

    // MARK: images.md

    @Test func withAccessEveryLocalImageShowsAndNothingElseDoes() throws {
        let html = HTMLRenderer.render(markdown: try Fixtures.text("images.md"), locateImage: Self.grantedLocator)
        #expect(html.components(separatedBy: "<img ").count - 1 == 13)
        let placeholders = Self.placeholderTexts(in: html)
        #expect(placeholders == [
            "This file does not exist", "A Markdown file, not an image", "Remote image",
            "Remote over HTTP", "Script source", "Data source",
        ])
        #expect(!html.contains("example.com/remote.png\" "), "a remote image must never be a src")
        #expect(html.contains("wide.png"))
    }

    @Test func withoutAccessEveryImageIsAPlaceholder() throws {
        let html = HTMLRenderer.render(markdown: try Fixtures.text("images.md"))
        #expect(!html.contains("<img "))
        #expect(Self.placeholderTexts(in: html).count == 19)
        #expect(Self.placeholderTexts(in: html).contains("sample.png"), "no alt text: the file name stands in")
    }

    @Test func imagesTheFileExpectsAreReallyThere() throws {
        let page = HTMLRenderer.renderPage(markdown: try Fixtures.text("images.md"))
        for reference in page.localReferences where !reference.contains("missing") && !reference.hasSuffix(".md") {
            let file = try #require(LocalReferences.resolve(reference, relativeTo: Self.imagesFile))
            #expect(FileManager.default.fileExists(atPath: file.path), "\(reference) should exist")
        }
    }

    // MARK: links.md

    enum Kind: Equatable { case external, markdown, file, scroll, ignore }

    /// What clicking each link in links.md should do, in page order.
    static let expectedLinks: [(href: String, kind: Kind)] = [
        ("#the-end", .scroll),
        ("links.md#web-and-mail", .scroll),
        ("links.md", .ignore),
        ("elements.md", .markdown),
        ("elements.md#tables-29", .markdown),
        ("edge/valid.md", .markdown),
        ("../fixtures/front-matter.md", .markdown),
        ("edge/with%20space.md", .markdown),
        ("missing.md", .markdown),
        ("images/sample.png", .file),
        ("images/", .file),
        ("edge/plain.txt", .file),
        ("missing.pdf", .file),
        ("https://example.com", .external),
        ("http://example.com", .external),
        ("mailto:someone@example.com", .external),
        ("https://example.com/bare", .external),
        ("https://example.com/angle", .external),
        ("elements.md", .markdown),
        ("https://example.com/reference", .external),
    ]

    @Test func everyLinkDoesWhatItShould() throws {
        let html = HTMLRenderer.render(markdown: try Fixtures.text("links.md"))
        let hrefs = Self.hrefs(in: html)
        #expect(hrefs == Self.expectedLinks.map(\.href))

        let base = URL(string: "mdview-file://document" + Fixtures.directory.path(percentEncoded: true) + "/")!
        for (href, expected) in Self.expectedLinks {
            let url = try #require(URL(string: href, relativeTo: base)).absoluteURL
            let route = LinkRoute.decide(url, document: Self.linksFile)
            #expect(Self.kind(of: route) == expected, "\(href) → \(route)")
        }
    }

    @Test func unsafeLinksAreTextOnly() throws {
        let html = HTMLRenderer.render(markdown: try Fixtures.text("links.md"))
        for text in ["JavaScript (shown as text only)", "Data URL (shown as text only)", "FTP (no link)"] {
            #expect(html.contains("<li>\(text)</li>"), "\(text) should not be a link")
        }
        #expect(!html.contains("javascript:") && !html.contains("data:text"))
    }

    @Test func linkedFilesExistExceptTheMissingOnes() throws {
        for (href, kind) in Self.expectedLinks where kind == .markdown || kind == .file {
            let file = try #require(LocalReferences.resolve(href, relativeTo: Self.linksFile))
            let exists = FileManager.default.fileExists(atPath: file.path)
            #expect(exists == !href.contains("missing"), "\(href): exists \(exists)")
        }
    }

    // MARK: Helpers

    static func kind(of route: LinkRoute) -> Kind {
        switch route {
        case .external: .external
        case .openMarkdown: .markdown
        case .openFile: .file
        case .scrollInPage: .scroll
        case .ignore: .ignore
        }
    }

    static func hrefs(in html: String) -> [String] {
        html.matches(of: /<a href="([^"]*)"/).map { String($0.1).replacingOccurrences(of: "&amp;", with: "&") }
    }

    static func placeholderTexts(in html: String) -> [String] {
        html.matches(of: /class="image-placeholder"[^>]*>([^<]*)<\/span>/).map { String($0.1) }
    }
}
