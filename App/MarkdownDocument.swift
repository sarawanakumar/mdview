import AppKit
import MDViewCore
import OSLog
import UniformTypeIdentifiers

/// One open file. Shown read-only; edit mode can change `text`, and File ▸
/// Save writes it back. Nothing else ever writes the file (ADR 0008).
final class MarkdownDocument: NSDocument {
    private nonisolated static let log = Logger(subsystem: "com.inferly.mdview", category: "document")

    /// The file's text, decoded as UTF-8 (spec 10.2).
    private(set) var text = ""
    /// True if some bytes weren't valid UTF-8 and were replaced.
    private(set) var hadInvalidBytes = false
    /// True if the file starts with a byte order mark; saving keeps it.
    private var hadByteOrderMark = false

    /// Edit mode is only offered for files that can be saved back exactly
    /// as they were read (spec 11.10): replacement characters must never
    /// be written over the original bytes.
    var canEdit: Bool { !hadInvalidBytes }

    /// Edit mode's text replaces the document's (spec 11.5). The edited
    /// state comes from the window's undo manager, which is the document's.
    func updateText(_ newText: String) {
        text = newText
    }

    /// False for files forced open that aren't Markdown (spec 10.5); those
    /// are shown as plain text.
    var isMarkdown: Bool {
        guard let fileType, let type = UTType(fileType) else { return false }
        return type.conforms(to: UTType("net.daringfireball.markdown") ?? .plainText)
    }

    // Saved only on File ▸ Save (spec 11.6): no autosave, no Versions.
    override class var autosavesInPlace: Bool { false }
    override class func isNativeType(_ type: String) -> Bool { false }

    /// The file is saved in the type it was read as, also for a plain-text
    /// file forced open (spec 10.5). Info.plist keeps the Viewer role, so
    /// without this NSDocument would treat the file as not writable.
    /// AppKit asks on the main thread: with autosave off and no
    /// asynchronous writing, saves start from the menu or the close question.
    override nonisolated func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        MainActor.assumeIsolated {
            // An untitled file's first save is a "save as" to NSDocument
            // (spec 12.3); without a type for it, NSDocument won't even ask
            // Save / Don't Save on close. Opened files only save in place.
            let allowed = saveOperation == .saveOperation || (fileURL == nil && saveOperation == .saveAsOperation)
            guard allowed, canEdit, let fileType else { return [] }
            return [fileType]
        }
    }

    /// Reads happen on the main thread. AppKit only reads documents in the
    /// background when this returns true, and `read` relies on that.
    override nonisolated class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        false
    }

    override nonisolated func read(from data: Data, ofType typeName: String) throws {
        let decoded = UTF8Text.decode(data)
        Signposts.signposter.emitEvent("documentRead")
        MainActor.assumeIsolated {
            text = decoded.text
            hadInvalidBytes = decoded.hadInvalidBytes
            hadByteOrderMark = decoded.hadByteOrderMark
            bytesOnDisk = data
            Self.log.info("""
                read document: type=\(typeName, privacy: .public) bytes=\(data.count, privacy: .public) \
                invalidUTF8=\(decoded.hadInvalidBytes, privacy: .public) markdown=\(self.isMarkdown, privacy: .public)
                """)
        }
    }

    // MARK: Saving (spec 11.6–11.8, 11.12)

    /// The bytes File ▸ Save writes: UTF-8, byte order mark kept, line
    /// endings as they are (`UTF8Text.encode`).
    override nonisolated func data(ofType typeName: String) throws -> Data {
        try MainActor.assumeIsolated {
            guard canEdit else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
            let data = Data(UTF8Text.encode(text, byteOrderMark: hadByteOrderMark))
            bytesBeingSaved = data
            return data
        }
    }

    /// Once a save has worked, its bytes are what's on disk, so the watcher
    /// seeing our own save changes nothing (spec 11.11): no reload, and the
    /// undo history stays.
    override func save(
        to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // Typing after the save must count as a new change, not join the
        // typing that was just saved (as TextEdit does).
        for case let controller as DocumentWindowController in windowControllers {
            controller.documentWillSave()
        }
        let wasUntitled = fileURL == nil
        super.save(to: url, ofType: typeName, for: saveOperation) { [weak self] error in
            if error == nil, let self, let saved = self.bytesBeingSaved { self.bytesOnDisk = saved }
            self?.bytesBeingSaved = nil
            // A new file's first save (spec 12.6): from now on it's like
            // any opened file, watched for changes and restored on relaunch.
            if error == nil, wasUntitled, let self, self.fileURL != nil {
                self.startWatching()
                for case let controller as DocumentWindowController in self.windowControllers {
                    controller.documentDidGetFile()
                }
            }
            completionHandler(error)
        }
    }

    /// An opened file is only ever saved back in place. If it has been
    /// deleted or moved away (spec 5.4), NSDocument would offer Save As,
    /// which would make a new file; say why it can't be saved instead (spec
    /// 11.12). An untitled file's first save goes to the save panel (12.3).
    override func save(_ sender: Any?) {
        guard fileURL != nil else { return super.save(sender) }
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else {
            let error = NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileNoSuchFile.rawValue, userInfo: [
                NSLocalizedDescriptionKey: "“\(displayName ?? "This file")” can’t be saved because it’s no longer available.",
                NSLocalizedRecoverySuggestionErrorKey: "It was deleted or moved away. Your edits are still in this window.",
            ])
            if let window = windowForSheet {
                presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
            } else {
                presentError(error)
            }
            return
        }
        super.save(sender)
    }

    /// The only save panel MDView shows: an untitled file's first save,
    /// also from the close and quit questions (spec 12.3, ADR 0009). It
    /// saves Markdown as `.md` and nothing else. For an opened file there's
    /// no Save As (ADR 0008): the panel is refused and the edits stay in
    /// the window, for example when its file is gone.
    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        guard fileURL == nil, let markdown = UTType(Self.markdownType) else {
            Self.log.info("save panel refused")
            return false
        }
        savePanel.allowedContentTypes = [markdown]
        savePanel.allowsOtherFileTypes = false
        savePanel.isExtensionHidden = false
        savePanel.canSelectHiddenExtension = false
        return true
    }

    /// No file format menu in the save panel: there's only one format.
    override var shouldRunSavePanelWithAccessoryView: Bool { false }

    override nonisolated func fileNameExtension(
        forType typeName: String, saveOperation: NSDocument.SaveOperationType
    ) -> String? {
        "md"
    }

    static let markdownType = "net.daringfireball.markdown"

    /// The `.md` stays visible: the save panel hides it when the name was
    /// typed without one, and then the window title would leave it out too.
    override nonisolated func fileAttributesToWrite(
        to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType,
        originalContentsURL absoluteOriginalContentsURL: URL?
    ) throws -> [String: Any] {
        var attributes = try super.fileAttributesToWrite(
            to: url, ofType: typeName, for: saveOperation, originalContentsURL: absoluteOriginalContentsURL
        )
        attributes[FileAttributeKey.extensionHidden.rawValue] = false
        return attributes
    }

    /// File ▸ Save is dimmed when there's nothing to save, so pressing ⌘S in
    /// the preview never touches the file.
    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(save(_:)) { return isDocumentEdited && canEdit }
        // Print prints the rendered preview, so only from the preview.
        if item.action == #selector(printDocument(_:)) {
            return !windowControllers.contains { ($0 as? DocumentWindowController)?.isEditing == true }
        }
        return super.validateUserInterfaceItem(item)
    }

    override func makeWindowControllers() {
        let controller = DocumentWindowController(document: self)
        addWindowController(controller)
        // A new, untitled file is for typing (spec 12.1). It has no file
        // to watch until it's saved.
        if fileURL == nil { controller.toggleEditMode(nil) }
        startWatching()
    }

    // MARK: Printing (spec 6.8)

    /// File ▸ Print… prints the rendered page (the print panel also offers
    /// Save as PDF). The page's print styles make it black on white at full
    /// width (preview.css).
    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        guard let info = printInfo.copy() as? NSPrintInfo else { throw CocoaError(.featureUnsupported) }
        info.dictionary().addEntries(from: printSettings)
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        guard let controller = windowControllers.first as? DocumentWindowController,
              let operation = controller.printOperation(with: info) else {
            throw CocoaError(.featureUnsupported)
        }
        operation.jobTitle = displayName
        return operation
    }

    override func close() {
        watcher?.stop()
        watcher = nil
        super.close()
    }

    // MARK: Changes on disk (spec section 5)

    private var watcher: FileWatcher?
    /// The file's bytes as last read or saved by MDView.
    private var bytesOnDisk: Data?
    private var bytesBeingSaved: Data?
    /// The Keep / Reload question is showing; further changes wait for it.
    private var isAskingAboutChange = false

    private func startWatching() {
        guard watcher == nil, let url = fileURL else { return }
        let watcher = FileWatcher(url: url) { [weak self] event in
            Task { @MainActor in self?.fileDidChange(event) }
        }
        self.watcher = watcher
        watcher.start()
    }

    /// The file was saved by another app (or came back). If its bytes are
    /// what MDView last read or saved, nothing changed. Otherwise show the
    /// new content, or, with unsaved edits, ask first (spec 11.11). If it
    /// can't be read right now, keep what we have; the next change will try
    /// again.
    private func fileDidChange(_ event: FileWatcher.Event) {
        guard let url = fileURL, let type = fileType else { return }
        switch event {
        case .changed:
            for case let controller as DocumentWindowController in windowControllers {
                controller.documentIsAvailable()
            }
            guard let data = try? Data(contentsOf: url) else {
                Self.log.info("changed on disk but couldn't be read")
                return
            }
            if data == bytesOnDisk {
                // Our own save, or the same file back again. Keep NSDocument's
                // date in step, so Save doesn't warn about another app.
                fileModificationDate = Self.modificationDate(of: url)
                return
            }
            if isDocumentEdited {
                askAboutOutsideChange(url: url, type: type, data: data)
            } else {
                reread(from: url, ofType: type)
            }
        case .disappeared:
            // Spec 5.4: deleted or moved away (including to the Trash). Keep
            // the last content and say the file is gone. The watcher keeps
            // checking and reports `.changed` if it comes back.
            Self.log.info("file no longer available")
            for case let controller as DocumentWindowController in windowControllers {
                controller.documentDidDisappear()
            }
        }
    }

    /// Unsaved edits and a different file on disk: Keep My Edits (saving
    /// later overwrites the other app's version) or Reload from Disk.
    private func askAboutOutsideChange(url: URL, type: String, data: Data) {
        guard !isAskingAboutChange else { return }
        isAskingAboutChange = true
        let alert = NSAlert()
        alert.messageText = "“\(displayName ?? "This file")” was changed by another app."
        alert.informativeText = "You have unsaved edits in MDView. Keep them, or reload the file from disk and lose them?"
        alert.addButton(withTitle: "Keep My Edits")
        alert.addButton(withTitle: "Reload from Disk")
        let answered: @MainActor (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self else { return }
            self.isAskingAboutChange = false
            if response == .alertSecondButtonReturn {
                self.reread(from: url, ofType: type)
            } else {
                // Don't ask again about this version (or a newer one that
                // came while asking), and let Save write over it without
                // NSDocument's own warning.
                self.bytesOnDisk = (try? Data(contentsOf: url)) ?? data
                self.fileModificationDate = Self.modificationDate(of: url)
            }
        }
        if let window = windowForSheet {
            alert.beginSheetModal(for: window) { response in MainActor.assumeIsolated { answered(response) } }
        } else {
            answered(alert.runModal())
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func reread(from url: URL, ofType type: String) {
        do {
            try revert(toContentsOf: url, ofType: type)
            for case let controller as DocumentWindowController in windowControllers {
                controller.documentDidChangeOnDisk()
            }
        } catch {
            Self.log.info("re-read failed: \(error.localizedDescription, privacy: .public)")
        }
    }

}
