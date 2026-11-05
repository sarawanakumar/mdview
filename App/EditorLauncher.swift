import AppKit
import OSLog
import UniformTypeIdentifiers

/// File ▸ Open in Editor (spec 6.10–6.12): the one app the user chose for
/// editing, remembered across launches.
///
/// MDView is usually the default app for Markdown, so there's no other
/// default to open in; the user picks one the first time. It's saved as a
/// bookmark, so it still works if the app is moved; if it's gone, the
/// choice is forgotten and the picker comes back.
@MainActor
final class EditorLauncher {
    static let shared = EditorLauncher()

    private static let defaultsKey = "EditorApplicationBookmark"
    private static let log = Logger(subsystem: "com.inferly.mdview", category: "editor")

    /// The remembered editor, if it's still there.
    var editor: URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI], bookmarkDataIsStale: &isStale),
              FileManager.default.fileExists(atPath: url.path) else {
            forget()  // deleted or unreachable (spec 6.12)
            return nil
        }
        if isStale { remember(url) }
        return url
    }

    /// The editor's name for the menu, e.g. "TextEdit".
    var editorName: String? {
        editor.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
    }

    func remember(_ app: URL) {
        guard let data = try? app.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    func forget() {
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    }

    /// Opens `file` in the remembered editor; with none remembered (or it's
    /// gone), asks first.
    func open(_ file: URL, from window: NSWindow) {
        if let editor {
            launch(file, in: editor)
        } else {
            chooseEditor(for: window) { [weak self] app in
                if let app { self?.launch(file, in: app) }
            }
        }
    }

    /// The app picker, as a sheet, starting in Applications (spec 6.10,
    /// 6.11). Calls `done` with the chosen app, or nil if cancelled.
    func chooseEditor(for window: NSWindow, done: @escaping @MainActor (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        panel.message = "Choose the app MDView should open files in for editing. You can change it later with File ▸ Change Editor…"
        panel.beginSheetModal(for: window) { [weak self] response in
            MainActor.assumeIsolated {
                guard response == .OK, let app = panel.url else { return done(nil) }
                if Bundle(url: app)?.bundleIdentifier == Bundle.main.bundleIdentifier {
                    let alert = NSAlert()
                    alert.messageText = "Choose an app other than MDView"
                    alert.informativeText = "MDView only shows files; pick the app you edit them in."
                    alert.beginSheetModal(for: window)
                    return done(nil)
                }
                self?.remember(app)
                done(app)
            }
        }
    }

    private func launch(_ file: URL, in app: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([file], withApplicationAt: app, configuration: configuration) { _, error in
            guard let error else { return }
            Task { @MainActor in
                Self.log.error("couldn't open in editor: \(error.localizedDescription, privacy: .public)")
                NSApp.presentError(error)
            }
        }
    }
}
