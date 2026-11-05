import Foundation
import Testing
@testable import MDViewCore

/// Spec 5.1, 5.3, 5.4 with real files, saved the ways editors save them.
@Suite("FileWatcher (5.1, 5.3, 5.4)", .serialized)
struct FileWatcherTests {
    /// A file in its own temporary folder, a watcher on it, and what the
    /// watcher reported.
    final class Harness: @unchecked Sendable {
        let folder: URL
        let file: URL
        private let lock = NSLock()
        private var events: [(FileWatcher.Event, ContinuousClock.Instant)] = []
        private(set) var watcher: FileWatcher!

        init(pollInterval: DispatchTimeInterval = .milliseconds(200)) throws {
            folder = FileManager.default.temporaryDirectory.appending(path: "mdview-watch-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            file = folder.appending(path: "note.md")
            try Data("# start\n".utf8).write(to: file)
            watcher = FileWatcher(url: file, pollInterval: pollInterval) { [weak self] event in
                guard let self else { return }
                self.lock.withLock { self.events.append((event, .now)) }
            }
            watcher.start()
            Thread.sleep(forTimeInterval: 0.1)  // let the watch begin
        }

        deinit {
            watcher.stop()
            try? FileManager.default.removeItem(at: folder)
        }

        var reported: [FileWatcher.Event] { lock.withLock { events.map(\.0) } }

        /// Waits until `count` events have arrived (or `limit` passes) and
        /// returns how long the last one took from `since`.
        func waitForEvents(_ count: Int, since: ContinuousClock.Instant, limit: Duration = .seconds(3)) -> Duration? {
            while ContinuousClock.now - since < limit {
                if let event = lock.withLock({ events.count >= count ? events[count - 1] : nil }) {
                    return event.1 - since
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
            return nil
        }

        func writeInPlace(_ text: String) throws {
            let handle = try FileHandle(forWritingTo: file)
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: Data(text.utf8))
            try handle.close()
        }

        /// Write a new file next to it, then rename it over the original,
        /// as many editors do.
        func saveByReplacing(_ text: String) throws {
            let temporary = folder.appending(path: ".note.md.tmp-\(UUID().uuidString)")
            try Data(text.utf8).write(to: temporary)
            guard rename(temporary.path, file.path) == 0 else { throw POSIXError(.EIO) }
        }
    }

    @Test func writeInPlaceIsReportedQuickly() throws {
        let harness = try Harness()
        let start = ContinuousClock.now
        try harness.writeInPlace("# edited\n")
        let elapsed = try #require(harness.waitForEvents(1, since: start))
        #expect(elapsed < .milliseconds(500))
        #expect(harness.reported == [.changed])
    }

    @Test func aBurstOfWritesIsOneChange() throws {
        let harness = try Harness()
        let start = ContinuousClock.now
        for index in 0..<10 { try harness.writeInPlace("# version \(index)\n") }
        _ = harness.waitForEvents(1, since: start)
        Thread.sleep(forTimeInterval: 0.3)
        #expect(harness.reported == [.changed])
    }

    @Test func saveByReplaceIsReportedAndLaterSavesToo() throws {
        let harness = try Harness()
        var start = ContinuousClock.now
        try harness.saveByReplacing("# replaced once\n")
        let first = try #require(harness.waitForEvents(1, since: start))
        #expect(first < .milliseconds(500))

        Thread.sleep(forTimeInterval: 0.2)
        start = .now
        try harness.saveByReplacing("# replaced twice\n")
        let second = try #require(harness.waitForEvents(2, since: start), "the second save must be seen too")
        #expect(second < .milliseconds(500))

        Thread.sleep(forTimeInterval: 0.2)
        start = .now
        try harness.writeInPlace("# then in place\n")
        #expect(harness.waitForEvents(3, since: start) != nil)
        #expect(harness.reported == [.changed, .changed, .changed])
    }

    @Test func atomicDataWritesAreSeen() throws {
        let harness = try Harness()
        for (index, text) in ["# a\n", "# b\n", "# c\n"].enumerated() {
            let start = ContinuousClock.now
            try Data(text.utf8).write(to: harness.file, options: .atomic)
            #expect(harness.waitForEvents(index + 1, since: start) != nil, "save \(index + 1)")
            Thread.sleep(forTimeInterval: 0.2)
        }
        #expect(harness.reported == [.changed, .changed, .changed])
    }

    @Test func deletedFileIsReportedThenFoundAgain() throws {
        let harness = try Harness()
        var start = ContinuousClock.now
        try FileManager.default.removeItem(at: harness.file)
        let gone = try #require(harness.waitForEvents(1, since: start))
        #expect(gone < .seconds(2))
        #expect(harness.reported == [.disappeared])

        start = .now
        try Data("# back\n".utf8).write(to: harness.file)
        let back = try #require(harness.waitForEvents(2, since: start), "the file coming back must be seen")
        #expect(back < .seconds(1))
        #expect(harness.reported == [.disappeared, .changed])

        // And it's watched again after coming back.
        Thread.sleep(forTimeInterval: 0.1)
        start = .now
        try harness.writeInPlace("# edited after return\n")
        #expect(harness.waitForEvents(3, since: start) != nil)
    }

    @Test func movedAwayAndBack() throws {
        let harness = try Harness()
        let elsewhere = harness.folder.appending(path: "moved.md")
        var start = ContinuousClock.now
        try FileManager.default.moveItem(at: harness.file, to: elsewhere)
        #expect(harness.waitForEvents(1, since: start) != nil)
        #expect(harness.reported == [.disappeared])

        start = .now
        try FileManager.default.moveItem(at: elsewhere, to: harness.file)
        #expect(harness.waitForEvents(2, since: start) != nil)
        #expect(harness.reported == [.disappeared, .changed])
    }

    @Test func nothingIsReportedAfterStop() throws {
        let harness = try Harness()
        harness.watcher.stop()
        try harness.writeInPlace("# after stop\n")
        try harness.saveByReplacing("# replaced after stop\n")
        Thread.sleep(forTimeInterval: 0.5)
        #expect(harness.reported.isEmpty)
    }

    @Test func startingOnAMissingFileWaitsForIt() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "mdview-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "later.md")
        let lock = NSLock()
        nonisolated(unsafe) var events: [FileWatcher.Event] = []
        let watcher = FileWatcher(url: file, pollInterval: .milliseconds(200)) { event in lock.withLock { events.append(event) } }
        watcher.start()
        defer { watcher.stop() }
        Thread.sleep(forTimeInterval: 1.3)
        try Data("# now\n".utf8).write(to: file)
        Thread.sleep(forTimeInterval: 0.6)
        #expect(lock.withLock { events } == [.disappeared, .changed])
    }
}
