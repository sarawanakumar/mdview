import Foundation
import Testing
@testable import MDViewCore

/// Spec 6.4 / 7.5: every text colour in the app's stylesheet has at least
/// 4.5:1 contrast with what it's drawn on, in light, dark and print.
/// Reads the real `App/Resources/preview.css`, so a later colour change
/// can't quietly break this.
@Suite("Colour contrast in preview.css (6.4, 7.5)")
struct ContrastTests {
    static let stylesheet: String = {
        let url = Fixtures.directory.deletingLastPathComponent().appending(path: "App/Resources/preview.css")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }()

    /// `--name: #rrggbb;` declarations in a block of CSS.
    static func colours(in css: Substring) -> [String: String] {
        var found: [String: String] = [:]
        for match in css.matches(of: /--([a-z-]+):\s*(#[0-9a-fA-F]{6})/) {
            found[String(match.1)] = String(match.2).lowercased()
        }
        return found
    }

    /// The light (first `:root`), dark and print colour sets.
    static var sets: (light: [String: String], dark: [String: String], print: [String: String]) {
        let css = stylesheet[...]
        let darkStart = css.range(of: "@media (prefers-color-scheme: dark)")!
        let printStart = css.range(of: "@media print")!
        let light = colours(in: css[..<darkStart.lowerBound])
        let dark = colours(in: css[darkStart.lowerBound..<css.index(darkStart.lowerBound, offsetBy: 600)])
        let print = colours(in: css[printStart.lowerBound...])
        return (light, dark, print)
    }

    /// WCAG 2 contrast ratio between two `#rrggbb` colours.
    static func contrast(_ a: String, _ b: String) -> Double {
        func luminance(_ hex: String) -> Double {
            let value = Int(hex.dropFirst(), radix: 16) ?? 0
            let channels = [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff].map { Double($0) / 255 }
            let linear = channels.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
        }
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Light pages are white; dark pages use the system Canvas colour,
    /// rgb(30, 30, 30), measured in the app (roadmap 2.8).
    static let pages = ["light": "#ffffff", "dark": "#1e1e1e"]

    /// (foreground, background) pairs that must reach 4.5:1.
    static let pairs: [(String, String)] = [
        ("tok-keyword", "code-bg"), ("tok-string", "code-bg"), ("tok-comment", "code-bg"), ("tok-number", "code-bg"),
        ("text", "code-bg"), ("muted", "code-bg"),
        ("text", "page"), ("muted", "page"), ("link", "page"),
        ("text", "stripe"),
    ]

    @Test func stylesheetIsFound() {
        #expect(Self.stylesheet.contains(".tok-keyword"))
    }

    @Test(arguments: ["light", "dark"])
    func everyPairReachesFourAndAHalfToOne(_ mode: String) throws {
        let colours = mode == "light" ? Self.sets.light : Self.sets.dark
        var report: [String] = []
        for (foreground, background) in Self.pairs {
            let fg = try #require(colours[foreground], "\(mode): --\(foreground) missing")
            let bg = background == "page" ? Self.pages[mode]! : try #require(colours[background], "\(mode): --\(background) missing")
            let ratio = Self.contrast(fg, bg)
            report.append(String(format: "%@ on %@ %.1f", foreground, background, ratio))
            #expect(ratio >= 4.5, "\(mode): --\(foreground) \(fg) on \(background) \(bg) is \(String(format: "%.2f", ratio)):1")
        }
        print("contrast (\(mode)): \(report.joined(separator: ", "))")
    }

    @Test func printUsesTheLightColours() {
        let (light, _, print) = Self.sets
        for (name, value) in print {
            #expect(light[name] == value, "print --\(name) should match light")
        }
        #expect(print.keys.contains("tok-keyword"), "print sets the code colours too")
    }

    @Test func knownContrastValues() {
        #expect(abs(Self.contrast("#000000", "#ffffff") - 21) < 0.01)
        #expect(abs(Self.contrast("#ffffff", "#ffffff") - 1) < 0.01)
    }
}
