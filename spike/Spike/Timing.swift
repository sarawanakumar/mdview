import Darwin
import Foundation
import OSLog

// Roadmap 0.4: timestamps for "double-click → first paint".
// All times are seconds since 1970 so an outside script can compare them
// with the moment it asked macOS to open the file.

enum Timing {
    static let signposter = OSSignposter(subsystem: "local.mdview.spike", category: .pointsOfInterest)

    static func now() -> Double { Date().timeIntervalSince1970 }

    /// When the kernel started this process (before any of our code ran).
    static func processStart() -> Double {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return 0 }
        let tv = info.kp_proc.p_un.__p_starttime
        return Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000
    }
}

/// App-wide moments, recorded once.
@MainActor
enum AppMarks {
    static let processStart = Timing.processStart()
    static var marks: [(String, Double)] = []

    static func mark(_ name: StaticString) {
        marks.append(("\(name)", Timing.now()))
        Timing.signposter.emitEvent(name)
    }
}

/// Moments for one opened document.
struct DocTiming {
    let name: String
    let bytes: Int
    var received = 0.0
    var read = 0.0
    var rendered = 0.0
    var loadCalled = 0.0
    var finished = 0.0

    @MainActor
    func report() -> String {
        let start = AppMarks.processStart
        func ms(_ t: Double) -> String { String(format: "%.0f", (t - start) * 1000) }
        let app = AppMarks.marks.map { "\($0.0)=\(ms($0.1))" }.joined(separator: " ")
        return """
        TIMING file=\(name) bytes=\(bytes) process_start=\(String(format: "%.3f", start)) \
        finished=\(String(format: "%.3f", finished)) | ms since process start: \(app) \
        received=\(ms(received)) read=\(ms(read)) rendered=\(ms(rendered)) \
        loadCalled=\(ms(loadCalled)) finished=\(ms(finished))
        """
    }
}
