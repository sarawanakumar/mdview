import AppKit
import OSLog

/// One window per file (spec 6.1): notice bars above the rendered preview.
final class DocumentWindowController: NSWindowController {
    private static let log = Logger(subsystem: "com.inferly.mdview", category: "folder-access")

    private let preview = PreviewController()
    private let stack = NSStackView()

    /// The folder access bar (spec 9.5), when shown, and the folder it
    /// offers.
    private var folderBar: NSView?
    private var suggestedFolder: URL?
    /// "Not Now" hides the bar for the rest of this window's life (9.7).
    private var folderBarDismissed = false

    /// Where the next window's top-left corner goes, so several open files
    /// fan out instead of stacking exactly on top of each other.
    private static var cascadePoint = NSPoint.zero

    init(document: MarkdownDocument) {
        // Wide enough for the 80-character column plus its margins
        // (preview.css: 16 px text, 28 px padding each side).
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        stack.orientation = .vertical
        stack.spacing = 0
        stack.distribution = .fill
        stack.alignment = .leading
        if document.hadInvalidBytes {
            add(Self.noticeBar(
                message: "Some of this file isn’t valid UTF-8 text, so it may not display correctly.",
                buttons: []
            ))
        }
        add(preview.view)
        preview.view.setContentHuggingPriority(.defaultLow, for: .vertical)
        window.contentView = stack
        if Self.cascadePoint == .zero { window.center() }
        Self.cascadePoint = window.cascadeTopLeft(from: Self.cascadePoint)

        preview.onFolderAccessNeeded = { [weak self] folder in self?.updateFolderBar(offering: folder) }
        NotificationCenter.default.addObserver(
            self, selector: #selector(folderAccessDidChange), name: FolderAccess.didChange, object: nil
        )
        preview.show(document)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    // MARK: Folder access (spec 9.5–9.7)

    private func updateFolderBar(offering folder: URL?) {
        suggestedFolder = folder
        guard let folder, !folderBarDismissed else {
            removeFolderBar()
            return
        }
        guard folderBar == nil else { return }
        let bar = Self.noticeBar(
            message: "Allow mdview to show images and linked files in this folder.",
            buttons: [
                Self.button("Allow…", action: #selector(allowFolder), target: self, isDefault: true),
                Self.button("Not Now", action: #selector(dismissFolderBar), target: self, isDefault: false),
            ]
        )
        bar.toolTip = folder.path(percentEncoded: false)
        stack.insertArrangedSubview(bar, at: 0)
        bar.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        folderBar = bar
    }

    private func removeFolderBar() {
        folderBar?.removeFromSuperview()
        folderBar = nil
    }

    @objc private func dismissFolderBar() {
        folderBarDismissed = true
        removeFolderBar()
    }

    /// The standard folder picker, as a sheet, starting at the suggested
    /// folder. Any folder can be chosen; one higher up covers more.
    @objc private func allowFolder() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = suggestedFolder
        panel.prompt = "Allow"
        panel.message = "mdview can show images and open linked files in the folder you choose and every folder inside it. Choosing a folder higher up, such as your home folder, means you won’t be asked again for anything in it."
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let folder = panel.url else { return }
            MainActor.assumeIsolated {
                do {
                    try FolderAccess.shared.grant(folder)
                } catch {
                    Self.log.error("couldn't save folder grant: \(error.localizedDescription, privacy: .public)")
                    NSApp.presentError(error)
                }
            }
        }
    }

    /// A grant anywhere may cover what this window needs: render again.
    @objc private func folderAccessDidChange() {
        guard suggestedFolder != nil else { return }
        preview.reload()
    }

    // MARK: Layout helpers

    private func add(_ view: NSView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    /// A slim bar above the content (spec 9.5, 10.2).
    private static func noticeBar(message: String, buttons: [NSButton]) -> NSView {
        let label = NSTextField(wrappingLabelWithString: message)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let bar = NSStackView(views: [label] + buttons)
        bar.orientation = .horizontal
        bar.spacing = 8
        bar.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        bar.setContentHuggingPriority(.required, for: .vertical)
        return bar
    }

    private static func button(_ title: String, action: Selector, target: AnyObject, isDefault: Bool) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.controlSize = .small
        button.bezelStyle = .push
        if isDefault { button.keyEquivalent = "\r" }
        return button
    }
}
