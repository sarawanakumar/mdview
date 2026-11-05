import AppKit
import MDViewCore
import OSLog

/// One window per file (spec 6.1): notice bars above the rendered preview.
final class DocumentWindowController: NSWindowController, NSMenuItemValidation {
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
        super.init(window: nil)
        // Start rendering before building the window, so the two overlap.
        preview.show(document)

        // Wide enough for the 80-character column plus its margins
        // (preview.css: 16 px text, 28 px padding each side).
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.window = window

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
        preview.onLink = { [weak self] route in self?.follow(route) }
        NotificationCenter.default.addObserver(
            self, selector: #selector(folderAccessDidChange), name: FolderAccess.didChange, object: nil
        )
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
            message: "Allow MDView to show images and linked files in this folder.",
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

    @objc private func allowFolder() {
        guard let suggestedFolder else { return }
        requestFolderAccess(startingAt: suggestedFolder) { _ in }
    }

    /// The standard folder picker, as a sheet, starting at `folder`. Any
    /// folder can be chosen; one higher up covers more. Calls `done` with
    /// whether a folder was granted.
    private func requestFolderAccess(startingAt folder: URL, done: @escaping @MainActor (Bool) -> Void) {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = folder
        panel.prompt = "Allow"
        panel.message = "MDView can show images and open linked files in the folder you choose and every folder inside it. Choosing a folder higher up, such as your home folder, means you won’t be asked again for anything in it."
        panel.beginSheetModal(for: window) { response in
            MainActor.assumeIsolated {
                guard response == .OK, let chosen = panel.url else { return done(false) }
                do {
                    try FolderAccess.shared.grant(chosen)
                    done(true)
                } catch {
                    Self.log.error("couldn't save folder grant: \(error.localizedDescription, privacy: .public)")
                    NSApp.presentError(error)
                    done(false)
                }
            }
        }
    }

    // MARK: Links (spec 4.1–4.6)

    private func follow(_ route: LinkRoute) {
        switch route {
        case .external(let url):
            NSWorkspace.shared.open(url)
        case .openMarkdown(let file, let fragment):
            withAccess(to: file) { [weak self] in self?.openMarkdown(file, fragment: fragment) }
        case .openFile(let file):
            withAccess(to: file) { [weak self] in self?.openFile(file) }
        case .scrollInPage, .ignore:
            break
        }
    }

    /// Runs `action` if mdview may read `file`; otherwise asks for its
    /// folder first, then runs it if the grant covers the file (spec 4.2).
    private func withAccess(to file: URL, then action: @escaping @MainActor () -> Void) {
        if FolderAccess.shared.covers(file) || file == documentFile {
            action()
            return
        }
        let start = documentFile.map { LocalReferences.suggestedFolder(for: $0, needing: [file]) }
            ?? file.deletingLastPathComponent()
        requestFolderAccess(startingAt: start) { granted in
            if granted, FolderAccess.shared.covers(file) { action() }
        }
    }

    private func openMarkdown(_ file: URL, fragment: String?) {
        guard FileManager.default.fileExists(atPath: file.path) else { return showNotFound(file) }
        NSDocumentController.shared.openDocument(withContentsOf: file, display: true) { document, _, error in
            if let error {
                NSApp.presentError(error)
                return
            }
            if let fragment,
               let controller = document?.windowControllers.first as? DocumentWindowController {
                controller.preview.scroll(toFragment: fragment)
            }
        }
    }

    private func openFile(_ file: URL) {
        guard FileManager.default.fileExists(atPath: file.path) else { return showNotFound(file) }
        if !NSWorkspace.shared.open(file) {
            showBriefNotice("MDView couldn’t open “\(file.lastPathComponent)”.")
        }
    }

    /// Spec 4.6: a link to a file that isn't there.
    private func showNotFound(_ file: URL) {
        showBriefNotice("“\(file.lastPathComponent)” wasn’t found.")
    }

    /// A notice bar that goes away by itself after a few seconds.
    private func showBriefNotice(_ message: String) {
        let bar = Self.noticeBar(message: message, buttons: [])
        stack.insertArrangedSubview(bar, at: 0)
        bar.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        NSAccessibility.post(element: bar, notification: .announcementRequested, userInfo: [
            .announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak bar] in bar?.removeFromSuperview() }
    }

    private var documentFile: URL? {
        (document as? MarkdownDocument)?.fileURL?.resolvingSymlinksInPath()
    }

    /// The file changed on disk (or came back) and has been read again
    /// (spec 5.1, 5.4).
    func documentDidChangeOnDisk() {
        removeMissingNotice()
        if let document = document as? MarkdownDocument { editor?.setText(document.text) }
        preview.reload()
    }

    // MARK: File no longer available (spec 5.4)

    private var missingNotice: NSView?

    /// The file was deleted or moved away: keep showing the last content,
    /// with a notice that stays until the file is back.
    func documentDidDisappear() {
        guard missingNotice == nil else { return }
        let name = window?.title ?? "This file"
        let message = "“\(name)” is no longer available. You’re seeing the last version; it will update if the file comes back."
        let bar = Self.noticeBar(message: message, buttons: [])
        stack.insertArrangedSubview(bar, at: 0)
        bar.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        missingNotice = bar
        NSAccessibility.post(element: bar, notification: .announcementRequested, userInfo: [
            .announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }

    private func removeMissingNotice() {
        missingNotice?.removeFromSuperview()
        missingNotice = nil
    }

    // MARK: Edit mode (spec 11.1–11.5, ADR 0008)

    /// Made on the first switch to edit mode, then kept (with its undo
    /// history) for the window's life.
    private var editor: SourceEditor?
    private(set) var isEditing = false
    /// The editor changed the text since the preview last rendered it.
    private var previewIsStale = false

    /// View ▸ Edit Mode: swaps the preview for the source editor, or back.
    @objc func toggleEditMode(_ sender: Any?) {
        guard let document = document as? MarkdownDocument else { return }
        if isEditing {
            isEditing = false
            editor?.view.isHidden = true
            preview.view.isHidden = false
            // Spec 11.5: the preview shows the editor's text, saved or not.
            if previewIsStale {
                previewIsStale = false
                preview.reload()
            }
            window?.makeFirstResponder(preview.view.subviews.first)
        } else {
            guard document.canEdit else { return }  // spec 11.10
            hideFindBar()
            let editor = editor ?? makeEditor(for: document)
            isEditing = true
            preview.view.isHidden = true
            editor.view.isHidden = false
            editor.focus(in: window)
        }
    }

    private func makeEditor(for document: MarkdownDocument) -> SourceEditor {
        let editor = SourceEditor(text: document.text)
        editor.setZoom(preview.zoom)
        editor.onChange = { [weak self, weak document] text in
            document?.updateText(text)
            self?.previewIsStale = true
        }
        add(editor.view)
        editor.view.setContentHuggingPriority(.defaultLow, for: .vertical)
        self.editor = editor
        return editor
    }

    // MARK: Find (spec 6.6)

    private lazy var findBar: FindBar = {
        let bar = FindBar()
        bar.target = preview
        bar.onClose = { [weak self] in self?.hideFindBar() }
        return bar
    }()
    private var isFindBarShown = false

    @objc func showFindBar(_ sender: Any?) {
        if isEditing, let editor { return editor.performFind(.showFindInterface) }  // spec 11.9
        if !isFindBarShown {
            stack.insertArrangedSubview(findBar.view, at: 0)
            findBar.view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            isFindBarShown = true
        }
        findBar.focus(in: window)
    }

    private func hideFindBar() {
        guard isFindBarShown else { return }
        findBar.view.removeFromSuperview()
        isFindBarShown = false
        window?.makeFirstResponder(preview.view.subviews.first)
    }

    /// Find Next / Previous: with nothing searched yet, open the bar instead.
    @objc func findNextMatch(_ sender: Any?) {
        if isEditing, let editor { return editor.performFind(.nextMatch) }
        findBar.searchText.isEmpty ? showFindBar(sender) : findBar.findNext()
    }

    @objc func findPreviousMatch(_ sender: Any?) {
        if isEditing, let editor { return editor.performFind(.previousMatch) }
        findBar.searchText.isEmpty ? showFindBar(sender) : findBar.findPrevious()
    }

    /// Searches for whatever is selected in the page.
    @objc func useSelectionForFind(_ sender: Any?) {
        if isEditing, let editor { return editor.performFind(.setSearchString) }
        Task {
            guard let text = await preview.selectedText() else { return }
            if !isFindBarShown { showFindBar(sender) }
            findBar.search(for: text)
        }
    }

    // MARK: Reveal in Finder (spec 6.9)

    @objc func revealInFinder(_ sender: Any?) {
        guard let file = documentFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }

    // MARK: Open in Editor (spec 6.10–6.12)

    @objc func openInEditor(_ sender: Any?) {
        guard let file = documentFile, let window else { return }
        EditorLauncher.shared.open(file, from: window)
    }

    @objc func changeEditor(_ sender: Any?) {
        guard let window else { return }
        EditorLauncher.shared.chooseEditor(for: window) { _ in }
    }

    // MARK: Printing (spec 6.8)

    func printOperation(with info: NSPrintInfo) -> NSPrintOperation? {
        preview.printOperation(with: info)
    }

    // MARK: Zoom (spec 6.7)

    @objc func zoomIn(_ sender: Any?) {
        if let next = ZoomLevels.zoomedIn(from: preview.zoom) { setZoom(next) }
    }

    @objc func zoomOut(_ sender: Any?) {
        if let next = ZoomLevels.zoomedOut(from: preview.zoom) { setZoom(next) }
    }

    @objc func actualSize(_ sender: Any?) {
        setZoom(ZoomLevels.actualSize)
    }

    /// One zoom per window, for the preview and the editor alike.
    private func setZoom(_ zoom: Double) {
        preview.setZoom(zoom)
        editor?.setZoom(zoom)
    }

    /// A grant anywhere may cover what this window needs: render again.
    @objc private func folderAccessDidChange() {
        guard suggestedFolder != nil else { return }
        preview.reload()
    }

    // MARK: Menu validation

    /// Greys out commands that wouldn't do anything.
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        let fileIsThere = missingNotice == nil && documentFile != nil
        switch item.action {
        case #selector(toggleEditMode(_:)):
            item.state = isEditing ? .on : .off
            return isEditing || (document as? MarkdownDocument)?.canEdit == true
        case #selector(zoomIn(_:)):
            return ZoomLevels.zoomedIn(from: preview.zoom) != nil
        case #selector(zoomOut(_:)):
            return ZoomLevels.zoomedOut(from: preview.zoom) != nil
        case #selector(actualSize(_:)):
            return !ZoomLevels.isActualSize(preview.zoom)
        case #selector(revealInFinder(_:)):
            return fileIsThere  // nothing to show while the file is gone (spec 5.4)
        case #selector(openInEditor(_:)):
            // "Open in TextEdit" once chosen (spec 6.11); "…" means it asks.
            item.title = EditorLauncher.shared.editorName.map { "Open in \($0)" } ?? "Open in Editor…"
            return fileIsThere
        default:
            return true
        }
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
