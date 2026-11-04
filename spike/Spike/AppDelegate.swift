import AppKit
import Markdown

// Throwaway spike app for roadmap M0. See docs/roadmap.md.
//
// 0.2: parses the bundled sample.md with swift-markdown and shows the tree.
// Run the binary with --dump to print the tree to stdout and exit.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    static func main() {
        if CommandLine.arguments.contains("--dump") {
            print(sampleTree())
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    static func sampleTree() -> String {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "sample.md not found in bundle" }
        return Document(parsing: text).debugDescription()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "mdview spike: sample.md tree"

        let scroll = NSTextView.scrollableTextView()
        if let textView = scroll.documentView as? NSTextView {
            textView.isEditable = false
            textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.string = Self.sampleTree()
        }
        window.contentView = scroll
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit Spike",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        let appItem = NSMenuItem()
        appItem.submenu = appMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(appItem)
        return mainMenu
    }
}
