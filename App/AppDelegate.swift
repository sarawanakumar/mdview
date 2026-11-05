import AppKit

/// mdview: a read-only Markdown viewer for macOS. See docs/vision.md.
///
/// Documents are handled by `MarkdownDocumentController` and
/// `MarkdownDocument`; the menu bar by `MainMenu`; the preview by
/// `PreviewController`.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        Signposts.signposter.emitEvent("appLaunched")
        let app = NSApplication.shared
        // The first document controller created becomes the shared one.
        _ = MarkdownDocumentController()
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Start WebKit's setup now, so it's ready when the first file arrives.
        PreviewConfiguration.shared()
        // Folders the user allowed earlier (spec 9.6), before any file opens.
        FolderAccess.shared.restore()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Signposts.signposter.emitEvent("launchFinished")
        NSApp.mainMenu = MainMenu.make()

        // Launched on its own (not to open a file): show the Open panel
        // rather than an empty window (spec 1.8). Wait one turn of the run
        // loop so restored windows count as open.
        let launchedOnItsOwn = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? false
        if launchedOnItsOwn {
            DispatchQueue.main.async { Self.showOpenPanelIfNothingIsOpen() }
        }
    }

    /// Clicking the Dock icon with no windows open also shows the Open
    /// panel, never an empty window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { Self.showOpenPanelIfNothingIsOpen() }
        return false
    }

    /// The standard About panel: icon, version and copyright come from the
    /// bundle; the credits say what mdview is and what it uses.
    @objc func showAbout(_ sender: Any?) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let credits = NSAttributedString(
            string: """
                A fast, read-only Markdown viewer that never goes online.

                Uses Apple’s swift-markdown (Apache License 2.0, © Apple Inc. \
                and the Swift project authors) and swift-cmark (BSD 2-Clause, \
                © John MacFarlane and others).
                """,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph,
            ]
        )
        // The bundle name is "mdview"; the name people see is MDView.
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "MDView", .credits: credits])
    }

    /// A viewer has nothing to create.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    private static func showOpenPanelIfNothingIsOpen() {
        guard NSDocumentController.shared.documents.isEmpty else { return }
        NSDocumentController.shared.openDocument(nil)
    }
}
