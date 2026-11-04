import AppKit
import Markdown
import WebKit

// Throwaway spike app for roadmap M0. See docs/roadmap.md.
//
// No arguments:  window with the locked-down web view test page (0.3).
// --dump:        print the swift-markdown tree of sample.md and exit (0.2).
// --check:       load the test page, print what loaded and exit (0.3).
// --no-rules:    with --check, skip the content rule list, to see whether
//                the sandbox alone blocks remote loads.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var window: NSWindow?
    private let handler = AssetSchemeHandler()
    private let checkMode = CommandLine.arguments.contains("--check")
    private let blockRemote = !CommandLine.arguments.contains("--no-rules")

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
        window.title = "mdview spike 0.3"
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate()

        Task {
            do {
                let webView = try await PreviewSpike.makeWebView(
                    handler: handler, blockRemote: blockRemote
                )
                webView.navigationDelegate = self
                window.contentView = webView
                webView.loadHTMLString(
                    PreviewSpike.html,
                    baseURL: URL(string: "\(PreviewSpike.scheme)://bundle/")
                )
            } catch {
                finish("SETUP FAILED: \(error)")
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard checkMode else { return }
        webView.evaluateJavaScript(PreviewSpike.checkScript) { [weak self] result, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                let report = (result as? String) ?? "check script failed: \(String(describing: error))"
                self.finish("""
                rules: \(self.blockRemote ? "on" : "off")
                page: \(report)
                scheme handler: \(self.handler.served)
                """)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        finish("NAVIGATION FAILED: \(error)")
    }

    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        finish("PROVISIONAL NAVIGATION FAILED: \(error)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish("WEB CONTENT PROCESS TERMINATED")
    }

    private func finish(_ message: String) {
        print(message)
        if checkMode { NSApp.terminate(nil) }
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
