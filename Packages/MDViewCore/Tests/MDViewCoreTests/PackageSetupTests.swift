import Markdown
import Testing
@testable import MDViewCore

/// Checks the package builds and links swift-markdown (roadmap 1.1).
@Test func swiftMarkdownIsLinked() {
    let document = Document(parsing: "# Hello")
    #expect(document.child(at: 0) is Heading)
}
