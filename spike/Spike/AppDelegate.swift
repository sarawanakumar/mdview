import AppKit
import Markdown
import WebKit

// Throwaway spike app for roadmap M0. See docs/roadmap.md.
//
// Opened with Markdown files (Finder, `open`): renders each in its own
//                window and prints a TIMING line when it has loaded (0.4).
// --dump:        print the swift-markdown tree of sample.md and exit (0.2).
// --check:       load the web view test page, print what loaded, exit (0.3).
// --no-rules:    with --check, skip the content rule list.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var windows: [NSWindow] = []
    private let handler = AssetSchemeHandler()
    private let checkMode = CommandLine.arguments.contains("--check")
    private let blockRemote = !CommandLine.arguments.contains("--no-rules")

    /// Started as early as possible so WebKit spins up while the file is read.
    private var configuration: Task<WKWebViewConfiguration, any Error>?
    /// One web view made ahead of time, used by the first document.
    private var spareWebView: WKWebView?
    private var timings: [ObjectIdentifier: DocTiming] = [:]

    static func main() {
        if CommandLine.arguments.contains("--dump") {
            print(sampleTree())
            return
        }
        _ = AppMarks.processStart
        AppMarks.mark("main")
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

    // MARK: Launch

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppMarks.mark("willFinishLaunching")
        let handler = handler
        let blockRemote = blockRemote
        configuration = Task {
            let config = try await PreviewSpike.makeConfiguration(handler: handler, blockRemote: blockRemote)
            AppMarks.mark("configReady")
            return config
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppMarks.mark("didFinishLaunching")
        NSApp.mainMenu = makeMainMenu()
        NSApp.activate()

        Task {
            guard let config = try? await configuration?.value else {
                finish("SETUP FAILED: web view configuration (rule list) unavailable")
                return
            }
            if checkMode {
                showCheckPage(config)
            } else if spareWebView == nil, windows.isEmpty {
                spareWebView = WKWebView(frame: .zero, configuration: config)
                AppMarks.mark("spareWebView")
            }
        }
    }

    // MARK: Opening documents

    func application(_ application: NSApplication, open urls: [URL]) {
        let received = Timing.now()
        for url in urls {
            Task { await openDocument(url, received: received) }
        }
    }

    private func openDocument(_ url: URL, received: Double) async {
        // Read, parse and render off the main thread.
        let rendered = await Task.detached { () -> (html: String, bytes: Int, read: Double, rendered: Double)? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            let read = Timing.now()
            let text = String(decoding: data, as: UTF8.self)
            let html = HTMLFormatter.format(Document(parsing: text, options: [.disableSmartOpts]))
            return (html, data.count, read, Timing.now())
        }.value

        guard let rendered else {
            finish("OPEN FAILED: could not read \(url.lastPathComponent)")
            return
        }
        guard let config = try? await configuration?.value else {
            finish("SETUP FAILED: web view configuration (rule list) unavailable")
            return
        }

        let webView = spareWebView ?? WKWebView(frame: .zero, configuration: config)
        spareWebView = nil
        webView.navigationDelegate = self

        let window = makeWindow(title: url.lastPathComponent)
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)

        var timing = DocTiming(name: url.lastPathComponent, bytes: rendered.bytes)
        timing.received = received
        timing.read = rendered.read
        timing.rendered = rendered.rendered
        timing.loadCalled = Timing.now()
        timings[ObjectIdentifier(webView)] = timing

        webView.loadHTMLString(
            PreviewSpike.page(title: url.lastPathComponent, body: rendered.html),
            baseURL: URL(string: "\(PreviewSpike.scheme)://bundle/")
        )
    }

    // MARK: Web view events

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if checkMode {
            runCheck(webView)
            return
        }
        guard var timing = timings.removeValue(forKey: ObjectIdentifier(webView)) else { return }
        timing.finished = Timing.now()
        Timing.signposter.emitEvent("documentLoaded")
        emit(timing.report())
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

    // MARK: 0.3 check page

    private func showCheckPage(_ config: WKWebViewConfiguration) {
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        let window = makeWindow(title: "mdview spike check")
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        webView.loadHTMLString(PreviewSpike.html, baseURL: URL(string: "\(PreviewSpike.scheme)://bundle/"))
    }

    private func runCheck(_ webView: WKWebView) {
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

    // MARK: Helpers

    private func makeWindow(title: String) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.center()
        windows.append(window)
        return window
    }

    private func emit(_ line: String) {
        print(line)
        fflush(stdout)
    }

    private func finish(_ message: String) {
        emit(message)
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
