import Foundation

/// Notices when a file changes on disk (spec 5.1, 5.3, 5.4).
///
/// Watches the file with a `DispatchSource` for writes, deletes and
/// renames. Many editors save by writing a new file and renaming it over
/// the old one; the old file's watch then ends, so after a delete or rename
/// the watcher looks for a file at the same path again and watches that.
///
/// - Bursts of events (an editor writing in several steps) become one
///   `.changed`, after `debounce`.
/// - If the file is gone and doesn't come back within about a second,
///   `.disappeared` is reported once; the watcher then checks every
///   `pollInterval` and reports `.changed` when the file is back.
///
/// Events are delivered on the watcher's own serial queue; hop to the main
/// thread if needed. Needs no AppKit, so it lives here and is unit tested.
public final class FileWatcher: @unchecked Sendable {
    public enum Event: Equatable, Sendable {
        case changed
        case disappeared
    }

    private let path: String
    private let debounce: DispatchTimeInterval
    private let pollInterval: DispatchTimeInterval
    private let handler: @Sendable (Event) -> Void

    /// All state below is only touched on `queue`.
    private let queue = DispatchQueue(label: "mdview.file-watcher")
    private var source: DispatchSourceFileSystemObject?
    private var pendingChange: DispatchWorkItem?
    private var poller: DispatchSourceTimer?
    private var isStopped = false

    /// How long to keep looking for a replaced file before calling it gone:
    /// 20 tries, 50 ms apart.
    private static let reattachAttempts = 20
    private static let reattachDelay: DispatchTimeInterval = .milliseconds(50)

    public init(
        url: URL,
        debounce: DispatchTimeInterval = .milliseconds(50),
        pollInterval: DispatchTimeInterval = .seconds(1),
        handler: @escaping @Sendable (Event) -> Void
    ) {
        self.path = url.path(percentEncoded: false)
        self.debounce = debounce
        self.pollInterval = pollInterval
        self.handler = handler
    }

    deinit {
        source?.cancel()
        poller?.cancel()
    }

    /// Starts watching. If the file isn't there, starts by looking for it.
    public func start() {
        queue.async { [self] in
            guard !isStopped, source == nil else { return }
            if !attach() { lookForFile(attempt: 0) }
        }
    }

    /// Stops watching; no events are delivered after this returns.
    public func stop() {
        queue.sync {
            isStopped = true
            pendingChange?.cancel()
            pendingChange = nil
            source?.cancel()
            source = nil
            poller?.cancel()
            poller = nil
        }
    }

    // MARK: Watching

    /// Opens the file for events and watches it. False if it isn't there.
    private func attach() -> Bool {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return false }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .revoke, .link],
            queue: queue
        )
        source.setEventHandler { [weak self, unowned source] in
            self?.handle(source.data)
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
        return true
    }

    private func detach() {
        source?.cancel()
        source = nil
    }

    private func handle(_ flags: DispatchSource.FileSystemEvent) {
        guard !isStopped else { return }
        if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
            // The file we were watching is gone or moved; a new one may
            // already be at the path (save by replace).
            detach()
            lookForFile(attempt: 0)
        } else {
            scheduleChange()
        }
    }

    /// Tries to watch the file at the path again, a few times, before
    /// reporting it as gone and falling back to polling.
    private func lookForFile(attempt: Int) {
        queue.asyncAfter(deadline: .now() + Self.reattachDelay) { [weak self] in
            guard let self, !self.isStopped, self.source == nil else { return }
            if self.attach() {
                self.scheduleChange()
            } else if attempt + 1 < Self.reattachAttempts {
                self.lookForFile(attempt: attempt + 1)
            } else {
                self.pendingChange?.cancel()
                self.pendingChange = nil
                self.handler(.disappeared)
                self.startPolling()
            }
        }
    }

    /// Checks now and then whether the file has come back (spec 5.4).
    private func startPolling() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            guard let self, !self.isStopped, self.source == nil else { return }
            if self.attach() {
                self.poller?.cancel()
                self.poller = nil
                self.handler(.changed)
            }
        }
        poller = timer
        timer.resume()
    }

    /// One `.changed` per burst of events.
    private func scheduleChange() {
        pendingChange?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isStopped else { return }
            self.pendingChange = nil
            self.handler(.changed)
        }
        pendingChange = work
        queue.asyncAfter(deadline: .now() + debounce, execute: work)
    }
}
