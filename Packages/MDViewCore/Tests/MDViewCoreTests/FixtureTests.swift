import Foundation
import Testing
@testable import MDViewCore

/// The Markdown files in the repository's `fixtures/` folder (spec.md,
/// "Test files"), and their expected HTML in `fixtures/expected/`.
enum Fixtures {
    /// `<repo>/fixtures`, found from this source file's location:
    /// `<repo>/Packages/MDViewCore/Tests/MDViewCoreTests/FixtureTests.swift`.
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // MDViewCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // MDViewCore
        .deletingLastPathComponent()   // Packages
        .deletingLastPathComponent()   // <repo>
        .appending(path: "fixtures")

    static let expectedDirectory = directory.appending(path: "expected")

    /// Paths of every `.md` / `.txt` fixture relative to `fixtures/`,
    /// excluding the expected-HTML folder. Sorted, so test names are stable.
    static let files: [String] = {
        guard let walker = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return [] }
        let root = directory.standardizedFileURL.path + "/"
        return walker.compactMap { $0 as? URL }
            .map { $0.standardizedFileURL.path }
            .filter { $0.hasPrefix(root) && !$0.hasPrefix(expectedDirectory.standardizedFileURL.path + "/") }
            .filter { $0.hasSuffix(".md") || $0.hasSuffix(".txt") }
            .map { String($0.dropFirst(root.count)) }
            .sorted()
    }()

    /// Renders a fixture the way the app does: Markdown through
    /// `renderSafely`, so deliberately deep files get the plain-text notice.
    static func render(_ relativePath: String) async throws -> String {
        let data = try Data(contentsOf: directory.appending(path: relativePath))
        let text = UTF8Text.decode(data).text
        return relativePath.hasSuffix(".md")
            ? await HTMLRenderer.renderSafely(markdown: text).html
            : HTMLRenderer.render(plainText: text)
    }

    /// Fixtures that are nested too deeply on purpose (spec 10.4).
    static let deliberatelyDeep: Set<String> = ["edge/deep-nesting.md"]

    static func expectedURL(for relativePath: String) -> URL {
        let html = (relativePath as NSString).deletingPathExtension + ".html"
        return expectedDirectory.appending(path: html)
    }

    static var isRecording: Bool {
        ProcessInfo.processInfo.environment["MDVIEW_RECORD_EXPECTED"] != nil
    }
}

@Suite("Fixtures")
struct FixtureTests {
    @Test func fixturesAreFound() {
        #expect(Fixtures.files.contains("elements.md"), "fixtures folder not found at \(Fixtures.directory.path)")
        #expect(Fixtures.files.contains("front-matter.md"))
    }

    /// Spec 10.4: any input renders something and never crashes.
    @Test(arguments: Fixtures.files)
    func rendersWithoutCrashing(_ file: String) async throws {
        let html = try await Fixtures.render(file)
        let source = try Data(contentsOf: Fixtures.directory.appending(path: file))
        if !source.isEmpty { #expect(!html.isEmpty) }
    }

    /// Output matches `fixtures/expected/<file>.html` when that file exists.
    /// With MDVIEW_RECORD_EXPECTED set, writes it instead.
    @Test(arguments: Fixtures.files)
    func matchesExpectedHTML(_ file: String) async throws {
        let html = try await Fixtures.render(file)
        let expectedURL = Fixtures.expectedURL(for: file)

        if Fixtures.isRecording {
            try FileManager.default.createDirectory(
                at: expectedURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try html.write(to: expectedURL, atomically: true, encoding: .utf8)
            return
        }
        guard let expected = try? String(contentsOf: expectedURL, encoding: .utf8) else {
            return  // No expected HTML recorded for this fixture yet.
        }
        #expect(html == expected, "\(file) differs from \(expectedURL.lastPathComponent); re-record if the change is intended")
    }
}
