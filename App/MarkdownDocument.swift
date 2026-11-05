import AppKit
import MDViewCore
import OSLog
import UniformTypeIdentifiers

/// One open file. Read-only: mdview never writes to it (ADR 0002).
final class MarkdownDocument: NSDocument {
    private nonisolated static let log = Logger(subsystem: "com.inferly.mdview", category: "document")

    /// The file's text, decoded as UTF-8 (spec 10.2).
    private(set) var text = ""
    /// True if some bytes weren't valid UTF-8 and were replaced.
    private(set) var hadInvalidBytes = false

    /// False for files forced open that aren't Markdown (spec 10.5); those
    /// are shown as plain text.
    var isMarkdown: Bool {
        guard let fileType, let type = UTType(fileType) else { return false }
        return type.conforms(to: UTType("net.daringfireball.markdown") ?? .plainText)
    }

    // A viewer: nothing to save, so no autosave and no "edited" state.
    override class var autosavesInPlace: Bool { false }
    override class func isNativeType(_ type: String) -> Bool { false }

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
            Self.log.info("""
                read document: type=\(typeName, privacy: .public) bytes=\(data.count, privacy: .public) \
                invalidUTF8=\(decoded.hadInvalidBytes, privacy: .public) markdown=\(self.isMarkdown, privacy: .public)
                """)
        }
    }

    override func makeWindowControllers() {
        addWindowController(DocumentWindowController(document: self))
        startWatching()
    }

    override func close() {
        watcher?.stop()
        watcher = nil
        super.close()
    }

    // MARK: Changes on disk (spec section 5)

    private var watcher: FileWatcher?

    private func startWatching() {
        guard watcher == nil, let url = fileURL else { return }
        let watcher = FileWatcher(url: url) { [weak self] event in
            Task { @MainActor in self?.fileDidChange(event) }
        }
        self.watcher = watcher
        watcher.start()
    }

    /// The file was saved by another app (or came back): read it again and
    /// show the new content. If it can't be read right now, keep showing
    /// what we have; the next change will try again.
    private func fileDidChange(_ event: FileWatcher.Event) {
        guard let url = fileURL, let type = fileType else { return }
        switch event {
        case .changed:
            reread(from: url, ofType: type)
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
