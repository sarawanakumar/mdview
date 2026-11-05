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

    /// A viewer has nothing to create.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    private static func showOpenPanelIfNothingIsOpen() {
        guard NSDocumentController.shared.documents.isEmpty else { return }
        NSDocumentController.shared.openDocument(nil)
    }
}
