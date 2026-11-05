// Times "ask macOS to open a file" → "rendered text visible" for mdview,
// against spec section 8 (8.1 cold, 8.2 warm, 8.3 large file).
//
// Usage, from the repository root, with a release build in build/:
//
//     swift scripts/time-open.swift [path/to/mdview.app] [runs]
//
// Defaults: build/mdview.app, 5 runs. Each run quits mdview, opens
// fixtures/typical.md cold, opens three other copies of it warm, then opens
// a generated 5 MB file. "Visible" is mdview's documentVisible signpost,
// read back with `log show`. Copies and the large file go in build/timing/
// (git-ignored): a file that's already open is only brought forward, so
// each warm open needs a file of its own.
//
// The first run after a rebuild is slow while macOS checks the new
// signature, so it isn't counted.

import Foundation

let arguments = CommandLine.arguments.dropFirst()
let app = URL(filePath: arguments.first ?? "build/mdview.app").absoluteURL.path
let runs = arguments.dropFirst().first.flatMap { Int($0) } ?? 5
let timing = URL(filePath: "build/timing", relativeTo: nil).absoluteURL
let typical = URL(filePath: "fixtures/typical.md").absoluteURL

guard FileManager.default.fileExists(atPath: app), let text = try? String(contentsOf: typical, encoding: .utf8) else {
    print("Run from the repository root, with a built app at \(app).")
    exit(1)
}

// MARK: Files

try FileManager.default.createDirectory(at: timing, withIntermediateDirectories: true)
func file(_ name: String) -> URL { timing.appending(path: name) }
for name in ["cold.md", "warm1.md", "warm2.md", "warm3.md"] {
    try text.write(to: file(name), atomically: true, encoding: .utf8)
}
let copies = Int((5_000_000 / Double(text.utf8.count)).rounded(.up))
try String(repeating: text + "\n", count: copies).write(to: file("large.md"), atomically: true, encoding: .utf8)

// MARK: Running things

@discardableResult
func run(_ tool: String, _ args: [String]) -> String {
    let process = Process()
    process.executableURL = URL(filePath: tool)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

func quitApp() {
    run("/usr/bin/pkill", ["-x", "mdview"])
    var tries = 0
    while tries < 50, !run("/usr/bin/pgrep", ["-x", "mdview"]).isEmpty {
        Thread.sleep(forTimeInterval: 0.1)
        tries += 1
    }
    Thread.sleep(forTimeInterval: 0.5)
}

/// Opens `url` in mdview, waits `wait` seconds, and returns the time from
/// the request to the first documentVisible signpost, in milliseconds.
func timeOpen(_ url: URL, wait: Double, extra: [String] = []) -> Double? {
    let start = Date()
    run("/usr/bin/open", ["-a", app, url.path] + extra)
    Thread.sleep(forTimeInterval: wait)
    return firstVisible(since: start).map { $0.timeIntervalSince(start) * 1000 }
}

func firstVisible(since start: Date) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let output = run("/usr/bin/log", [
        "show", "--start", formatter.string(from: start.addingTimeInterval(-1)), "--signpost", "--style", "ndjson",
        "--predicate", "subsystem == \"com.inferly.mdview\"",
    ])
    let stamp = DateFormatter()
    stamp.locale = Locale(identifier: "en_US_POSIX")
    stamp.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
    return output.split(separator: "\n").compactMap { line -> Date? in
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              object["signpostName"] as? String == "documentVisible",
              let time = (object["timestamp"] as? String).flatMap(stamp.date(from:)), time >= start else { return nil }
        return time
    }.min()
}

// MARK: Measuring

print("mdview open timing: \(app), \(runs) runs, load average \(run("/usr/sbin/sysctl", ["-n", "vm.loadavg"]).trimmingCharacters(in: .whitespacesAndNewlines))")
var cold: [Double] = [], warm: [Double] = [], large: [Double] = []

quitApp()
_ = timeOpen(file("cold.md"), wait: 3, extra: ["--args", "-ApplePersistenceIgnoreState", "YES"])  // signature check run

for index in 1...runs {
    quitApp()
    let c = timeOpen(file("cold.md"), wait: 2.5, extra: ["--args", "-ApplePersistenceIgnoreState", "YES"])
    let w = (1...3).compactMap { timeOpen(file("warm\($0).md"), wait: 1.5) }
    let l = timeOpen(file("large.md"), wait: 6)
    if let c { cold.append(c) }
    warm += w
    if let l { large.append(l) }
    let shown = { (value: Double?) in value.map { String(format: "%4.0f", $0) } ?? "   -" }
    print("run \(index): cold \(shown(c)) ms, warm \(w.map { shown($0) }.joined(separator: " ")) ms, large \(shown(l)) ms")
}
quitApp()

func report(_ name: String, _ values: [Double], target: Double) {
    guard !values.isEmpty else { print("\(name): no measurements"); return }
    let sorted = values.sorted()
    let median = sorted[sorted.count / 2]
    let verdict = median < target ? "pass" : "MISS"
    print(String(format: "%@: median %.0f ms (min %.0f, max %.0f, n=%d), target under %.0f ms: %@",
                 name, median, sorted[0], sorted[sorted.count - 1], sorted.count, target, verdict))
}
let largeSize = (try? FileManager.default.attributesOfItem(atPath: file("large.md").path)[.size] as? Int) ?? 0
print("")
report("8.1 cold, typical.md", cold, target: 500)
report("8.2 warm, typical.md", warm, target: 200)
report(String(format: "8.3 large, %.1f MB", Double(largeSize) / 1_000_000), large, target: 2000)
