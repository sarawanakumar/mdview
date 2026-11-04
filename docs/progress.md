# Progress

Newest session first.

## 2026-11-04: Roadmap 0.3, web view in the sandbox

**Done**
- Spike now shows a hard-coded test page in a locked-down `WKWebView`:
  page JavaScript off, non-persistent data store, a content rule list
  blocking everything except `mdview-file:`, and a minimal
  `AssetSchemeHandler` serving `pic.png` from the app bundle
  (`spike/Spike/PreviewSpike.swift`).
- `--check` mode loads the page, reports what loaded and quits;
  `--no-rules` skips the block list. Run via
  `open -n -W --stdout <file> Spike.app --args --check`.

**Result: risk 2 fails on macOS 26.6.** In a sandboxed app *without* the
outgoing-network entitlement (`com.apple.security.network.client`),
WebKit's web content and GPU helper processes fail to launch ("web
process failed to launch", reason Crash), so nothing renders. Tested by
re-signing copies of the same build:

| Variant | Result |
|---|---|
| Sandbox, no network entitlement (current design) | Web process fails to launch |
| Same, hardened runtime off | Still fails |
| Sandbox + `network.client` | Works |
| No sandbox | Works |

When it works (network.client or no sandbox):
- Page script did **not** run (JavaScript off works).
- Local image loaded through `mdview-file://` (64 px wide; handler log
  `OK mdview-file://bundle/pic.png (2149 bytes)`).
- Remote image (`https://www.apple.com/favicon.ico`) blocked by the rule
  list (width 0). With `--no-rules` it **did** load (width 64), so the
  rule list is what stops remote loads.
- Not tested: macOS 15 (only macOS 26.6 available here).

**Open (needs owner decision):** ADR 0003 (web view) and ADR 0005
(sandbox with no network entitlement) can't both stand as written.
Options:
1. Keep web view and sandbox, add the outgoing-network entitlement.
   Offline is then enforced by WebKit's block list, JavaScript off and no
   networking code, checked by a network monitor (spec 7.3), not by
   macOS. Sandbox still limits file access.
2. Switch rendering to a native text view (ADR 0003's fallback). macOS
   keeps enforcing "no network", at the cost of much more layout code.
3. Drop the sandbox. Loses file-access limits as well; no advantage
   over option 1.

**Decided: option 1.** Recorded as ADR 0006 (ADR 0005 point 1 amended).
- Spike now has `com.apple.security.network.client` (entitlements file
  and `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES`). Rebuilt from the
  project: entitlements are sandbox + user-selected read-only +
  network.client. `--check` passes: script didn't run, local image 64 px,
  remote image blocked. `--no-rules` loads the remote image (first try
  hit the 40 s alarm, retry succeeded; likely slow network).
- Spec 9.1 reworded (network monitor is the proof); new 9.8 (don't show a
  page if the block list fails). CLAUDE.md network rule updated.
  Architecture risks 2 and 3 marked with results. Roadmap 3.4 now
  includes an automated block-list test.
- Roadmap 0.3 ticked.

**Next**
- Roadmap 0.4: open a real `.md` from Finder and time double-click →
  first paint, cold and warm.

## 2026-11-04: Roadmap 0.2, swift-markdown check

**Done**
- Added `swift-markdown` to the spike, pinned to exactly **0.9.0** (latest,
  released Sept 2026). Resolved packages: `swift-markdown` 0.9.0 and
  `swift-cmark` 0.9.0 only; `Package.resolved` is in
  `spike/Spike.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`.
- `spike/Spike/sample.md` covers every spec section 2 element plus front
  matter, footnotes, bare URLs, inline and block HTML.
- The spike shows the parsed tree in its window; running
  `Spike.app/Contents/MacOS/Spike --dump` prints it and exits.

**Results**
- Parse correctly: headings, emphasis, bold+italic, inline code,
  `~~strike~~` and `~strike~`, links, soft and hard line breaks, nested
  lists 4 deep, ordered list start number (3), task lists (`[ ]`/`[x]`),
  nested quotes with lists, fenced code with language tag, indented code,
  tables with left/centre/right alignment, horizontal rules, images.
- Inline HTML and HTML blocks come out as their own nodes, so escaping
  them (spec 2.12) is straightforward.
- **Front matter** is not recognised: it parses as a horizontal rule plus
  an H2 heading. Confirms it must be stripped before parsing.
- **Footnotes** are not supported (no footnote nodes in the source; text
  stays literal). Recorded as out of scope in spec.md.
- **Bare URLs** (`https://example.com` without `<>`) are not turned into
  links; GitHub does this. Angle-bracket autolinks work.
- **Smart punctuation** is on by default: `"x"` → “x”, `--` → –,
  `...` → …. GitHub doesn't do this. Can be turned off with
  `.disableSmartOpts`.
- Size: Release universal app 3.3 MB unstripped, **2.2 MB stripped**
  (about 1.1 MB per chip type). Up from 176 KB before the package.
- Build succeeded with no Swift warnings.

**Decided**
- Bare web addresses become links, done by our renderer (spec 2.14).
- Smart punctuation off, text shows as written (spec 2.15).
- Old spec 2.14 (reference file) is now 2.16. Both added to roadmap 2.7.

**Next**
- Roadmap 0.3: locked-down `WKWebView` in the sandbox with one image via
  `mdview-file://`.

## 2026-11-04: Roadmap 0.1, git and spike project

**Done**
- `git init` on branch `main`, with a `.gitignore` (Xcode build output,
  user data, SwiftPM caches, `.claude/settings.local.json`). Nothing
  committed yet.
- Spike Xcode project at `spike/Spike.xcodeproj` (throwaway, per M0).
  AppKit app, set up in code with `@main`; shows one window with a label
  and a Quit menu item. Uses Xcode's folder-synced groups, so new files in
  `spike/Spike/` are picked up without editing the project file.
- Settings: Swift 6, macOS 15.0 minimum, App Sandbox on with only
  "user-selected files: read-only", no network entitlements, hardened
  runtime, signed to run locally (ad hoc). Bundle ID
  `local.mdview.spike` (placeholder).
- Built with Xcode 26.6 / Swift 6.3.3 on macOS 26.6.2 (Apple silicon).

**Checked**
- Debug and Release builds succeed, with no compiler warnings.
- Release build: universal (`x86_64 arm64`), `minos 15.0`, entitlements
  are exactly app-sandbox + user-selected read-only (debug entitlement
  removed), hardened runtime flag set. Size 176 KB.
- Launched the Release app: it ran, and macOS created its sandbox
  container (`~/Library/Containers/local.mdview.spike`).
- Not checked: the window on screen (no screen access from the shell).

**Build commands**
- Debug: `xcodebuild -project spike/Spike.xcodeproj -scheme Spike build`
- Release, universal: add `-configuration Release -destination
  'generic/platform=macOS'`. Without the destination, Release builds only
  for the current Mac's architecture.

**Next**
- Roadmap 0.2: add `swift-markdown` and check what it parses.

## 2026-11-04: Planning docs

**Done**
- Created the project skeleton and README.
- Wrote `vision.md`. Decisions: swift-markdown is the one allowed package;
  code highlighting is in v1; minimum macOS 15 Sequoia.
- Wrote `spec.md` with acceptance criteria. Decisions: hide YAML front
  matter; "Open in Editor" remembers one chosen editor.
- Wrote `architecture.md` and ADRs 0001–0005. All five accepted.
- Updated the spec for ADR 0005: 9.2 changed, new 9.5–9.7 (folder access
  bar), and 3.1, 3.2, 4.2 note they need a folder grant.

**Open**
- Footnotes: check `swift-markdown` support in the first spike.
- Distribution approach (before first release).

- Wrote `roadmap.md`: milestones M0 (risk spike) to M7 (v1 release).

- Wrote `CLAUDE.md`: session start/end routine, hard rules, code,
  testing, git and doc conventions.

**Next**
- Start roadmap task 0.1 (git and Xcode project).
- Fill in `.claude/settings.json` (permissions) once build commands exist.
