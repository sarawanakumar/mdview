# Progress

Newest session first.

## 2026-11-04: Roadmap 1.5, first preview

**Done**
- `MDViewCore/HTMLEscaping` and a minimal `HTMLRenderer`: headings and
  paragraphs rendered; inline formatting shown as its text; soft and hard
  breaks; every other block shown as escaped source in
  `<pre class="not-yet-rendered">` so nothing is lost or interpreted;
  smart punctuation off; plain-text files in `<pre class="plain-text">`.
  13 new tests (20 total), including inline and block HTML never
  becoming markup.
- `App/PreviewConfiguration.swift`: one shared configuration, started in
  `applicationWillFinishLaunching`: page JavaScript off, non-persistent
  store, block list (`mdview-block-remote-v1`, looked up before
  compiling), `mdview-file:` scheme. If the block list can't be loaded,
  the window shows a message instead of the file (spec 9.8).
- `App/AssetSchemeHandler.swift`: stub that fails every request (3.3
  fills it in).
- `App/PreviewController.swift`: renders off the main thread, then shows
  the page in a web view; only our own page load is allowed, link clicks
  are cancelled for now; reloads the page if WebKit's page process dies.
  `PageShell` adds the inlined CSS and a Content Security Policy
  (`default-src 'none'`) as an extra layer.
- `App/Resources/preview.css`: system font, 80-character column, heading
  sizes and rules, light/dark colours.
- Document windows now show the preview instead of the temporary text
  view.

**Checked**
- 20 core tests pass. Debug and Release build with no warnings (one
  build error on the way: a main-thread-only constant used from a
  non-main context; fixed).
- With a temporary page summary (removed afterwards), opened 5 files:

| File | Page |
|---|---|
| valid.md | H1 "Valid", 1 paragraph, "café ✓" intact |
| latin1.md | H1 "Caf� menu", 1 paragraph |
| plain.txt | 1 plain-text block; `#` line not a heading |
| empty.md | empty page |
| spike sample.md | 5 headings, 7 paragraphs, 10 blocks shown as source; its `<b>`/`<div>` created no elements; 0 scripts |

- All pages: system body font, column 649 px (80 characters). 5 windows
  on screen.
- Not checked: how it looks (no screen access), dark mode, the notice
  bar above the preview, and the spec 9.8 error path (couldn't force the
  block list to fail).

**Next**
- Roadmap 1.6: multiple files, Dock drop, bring already-open files to
  the front, unreadable-file alert.

## 2026-11-04: Roadmap 1.4, menus and the Open panel

**Done**
- `App/MainMenu.swift`: menu bar in code. mdview (About, Services,
  Hide ⌘H, Hide Others ⌥⌘H, Show All, Quit ⌘Q), File (Open… ⌘O, Open
  Recent, Close ⌘W), Edit (Copy ⌘C, Select All ⌘A), Window (Minimize ⌘M,
  Zoom, Bring All to Front; set as the windows menu so macOS adds the
  window list and tab commands), Help (empty; macOS adds its search
  field). Items target the responder chain so AppKit enables them.
- `App/RecentDocumentsMenu.swift`: fills Open Recent from AppKit's
  recent-documents list each time it opens (file icon, full path as
  tooltip, then Clear Menu). AppKit only manages this menu by itself in
  XIB-based menus; in code it needs a private API, which we avoid.
- `AppDelegate`: launched on its own → Open panel, never an empty window
  (spec 1.8). Clicking the Dock icon with nothing open does the same.
  Launched to open a file → no panel.

**Checked** (with a temporary in-app dump of menus and windows, removed
afterwards; launched with `open -a build/mdview.app`)
- Menus and shortcuts as listed. macOS adds its own extras: Close All
  (⌥⌘W) in File; AutoFill, Start Dictation and Emoji & Symbols in Edit.
- Launched on its own: an `NSOpenPanel` ("Open", 880×448) is the only
  visible window. Spec 1.8 passes.
- Launched with a file: just that file's window, no panel.
- Open Recent lists files from earlier launches, newest first, then a
  separator and Clear Menu. Choosing `valid.md` from a previous launch
  opened it in the sandbox (log shows the new process reading 42 bytes).
  Spec 1.7 passes.
- Open panel filtering (spec 1.3): the panel uses the document types from
  Info.plist; not visually checked.
- Debug and Release build with no warnings; 7 core tests pass.

**Found**
- Ad hoc signed builds forget the recent list when rebuilt (each build
  has a new signature, so the sandbox's saved access no longer matches).
  Same build across launches keeps it. A consistently signed release
  won't have this; worth noting for distribution (roadmap 7.5).

**Next**
- Roadmap 1.5: the locked-down web view showing a minimal HTML version
  of the file.

## 2026-11-04: Roadmap 1.3, read-only MarkdownDocument

**Done**
- `MDViewCore/UTF8Text`: decodes bytes as UTF-8, drops a leading byte
  order mark, replaces invalid bytes with U+FFFD and reports that it did.
  6 unit tests (valid, empty, BOM, BOM only, invalid bytes, Latin-1).
- `App/MarkdownDocument.swift`: read-only `NSDocument` (not a native
  type, no autosave). Reads on the main thread only
  (`canConcurrentlyReadDocuments` is false; `read` asserts it). Logs
  type, size and whether UTF-8 was invalid (no file names or content).
  `isMarkdown` is false for non-Markdown files.
- `App/MarkdownDocumentController.swift`: opens every file type as a
  `MarkdownDocument`, so Open With → Other works (spec 10.5). Created in
  `main` so it's the shared controller.
- `App/DocumentWindowController.swift`: one window per file showing the
  text in a read-only monospaced text view, with a notice bar when the
  file wasn't valid UTF-8. **Temporary**: 1.5 replaces it with the
  preview.
- Info.plist names the document class. No untitled document at launch.
- `fixtures/edge/`: `empty.md`, `latin1.md` (invalid UTF-8),
  `plain.txt`, `valid.md`.

**Checked**
- `swift test`: 7 tests pass.
- Debug and Release build with no warnings (first build had four Swift 6
  concurrency warnings in `read`; fixed as above).
- Opened each edge file with `open -a build/mdview.app`; the app's log:

| File | Type | Bytes | Invalid UTF-8 | Markdown |
|---|---|---|---|---|
| valid.md | net.daringfireball.markdown | 42 | no | yes |
| empty.md | net.daringfireball.markdown | 0 | no | yes |
| latin1.md | net.daringfireball.markdown | 91 | **yes** | yes |
| plain.txt | public.plain-text | 72 | no | **no** |

- Window server: 4 mdview windows on screen, 760×712 each, no error
  alerts. Spec 10.1, 10.2 (detection) and 10.5 (opens) pass; spec 1.2's
  "double-click opens it in mdview" now works too.
- Not checked: what the windows show (no screen access). The notice bar
  and text need a visual check.
- Log noise from macOS (App Intents connection, a missing system
  database) also appeared in the spike; not mdview errors.

**Next**
- Roadmap 1.4: menus in code and the Open panel at launch.

## 2026-11-04: Roadmap 1.2, Markdown file types

**Done**
- `App/Resources/Info.plist`, merged with the generated one (excluded
  from the bundle's resources via the synced group's exceptions):
  - Document type "Markdown document", role Viewer, rank **Alternate**
    (offered, never takes over by itself).
  - macOS declares `net.daringfireball.markdown` for `.md` and
    `.markdown` only, and an app can't add extensions to it (importing
    the type with extra extensions had no effect). So mdview exports its
    own `com.inferly.mdview.markdown-extension` for `.mdown` and `.mkd`,
    conforming to Markdown and plain text. Spec "Supported files" updated.
- Unregistered the old spike builds from LaunchServices (they had
  registered as Markdown viewers in 0.4).

**Checked** (Release build copied to `build/`, registered with
`lsregister -f`, then asked `NSWorkspace` which apps can open test files)

| File | mdview offered | Default (unchanged) |
|---|---|---|
| `.md` | yes | Xcode |
| `.markdown` | yes | Xcode |
| `.mdown` | yes | Visual Studio Code |
| `.mkd` | yes | Visual Studio Code |
| `.txt` | no (correct) | TextEdit |

- Spec 1.1 passes. Spec 1.2: mdview can be chosen as default (it's
  offered for every extension); "double-clicking then opens it" needs the
  document class from roadmap 1.3. I didn't change your default app.
- Found: apps in temporary folders (the build output in the session
  scratchpad, under `/private/tmp`) are registered but **not offered** in
  Open With. Noted in CLAUDE.md.
- `build/mdview.app` is still registered, so mdview shows in your Open
  With menu. It can't open files until 1.3 (macOS will show an error).

**Next**
- Roadmap 1.3: `MarkdownDocument`, read-only NSDocument.

## 2026-11-04: Roadmap 1.1, real project layout

**Done**
- Bundle ID **`com.inferly.mdview`** (owner's choice). Version 0.1.0.
- `mdview.xcodeproj`: app target `mdview`, folder-synced group `App/`,
  Swift 6, macOS 15.0 minimum, hardened runtime, ad hoc signing,
  sandbox + user-selected read-only + outgoing network (ADR 0006), no
  incoming network. Release drops the debug entitlement.
- `App/AppDelegate.swift`: launches with a Quit menu only.
  `App/mdview.entitlements` is excluded from the bundle via the synced
  group's exception list.
- `Packages/MDViewCore`: local Swift package (tools 6.0, macOS 15),
  depends on swift-markdown exactly 0.9.0, linked into the app. Empty
  `MDViewCore` namespace plus one Swift Testing test that checks
  swift-markdown is linked.
- `fixtures/` created (empty).
- README (layout, build commands), CLAUDE.md (build and test commands),
  architecture.md (entitlements location) updated.

**Checked**
- `swift test --package-path Packages/MDViewCore`: 1 test passed.
- Debug and Release builds succeed, no Swift warnings. Schemes: `mdview`,
  `MDViewCore`.
- Release app: universal (x86_64, arm64), bundle ID, display name and
  macOS 15.0 minimum correct; entitlements exactly as above; no stray
  files copied into the bundle; swift-markdown's parser is linked in.
- Launched with `open`: runs, and macOS created
  `~/Library/Containers/com.inferly.mdview`.
- Package.resolved pins swift-markdown and swift-cmark 0.9.0 for both the
  package and the Xcode project.
- Not checked: nothing visible yet (no window by design until 1.4).

**Next**
- Roadmap 1.2: register the Markdown file types.

## 2026-11-04: Roadmap 0.6, M0 summary

M0 is done. Every risk in architecture.md has a measured answer, and the
architecture holds with one change (ADR 0006).

**Risks**

| Risk | Result | Task |
|---|---|---|
| 1. Cold open < 0.5 s with WKWebView | Yes: cold median 359 ms, warm 172 ms (50 KB) | 0.4 |
| 2. WKWebView in the sandbox without network entitlement | **No**: WebKit won't launch. Fixed by granting outgoing network (ADR 0006); block list verified | 0.3 |
| 3. swift-markdown coverage | All spec 2 elements parse. No footnotes (out of scope); bare URLs and front matter handled by us | 0.2 |
| 4. Size < 5 MB | 2.2 MB universal, stripped | 0.5 |
| Extra: memory < 100 MB (spec 8.5) | 86 MB total: app 26, WebContent 40, GPU 17 (135 MB peak briefly at start), Networking 5 | 0.6 |

**ADRs**

| ADR | Still stands? |
|---|---|
| 0001 swift-markdown only | Yes. Pinned 0.9.0; only swift-cmark comes with it |
| 0002 AppKit + NSDocument | Yes, not contradicted. The spike used plain AppKit; NSDocument itself is first tried in M1 |
| 0003 WKWebView, JS off | Yes. Speed, size and memory within targets |
| 0004 hand-written highlighter | Yes, untested until M6. Parse + render left plenty of time budget (~4 ms for 50 KB) |
| 0005 sandbox, scheme, folder grants | Yes, except point 1 (no network entitlement), replaced by ADR 0006. The `mdview-file://` handler works |
| 0006 outgoing-network entitlement | Yes, new in M0 |

**Things to carry into M1**
- Create the spare web view in `applicationWillFinishLaunching`, before
  the file arrives, and make a new one after each use (the spike's was
  too late).
- Memory is the tightest target (86 of 100 MB). Re-measure when the real
  CSS, highlighter and images arrive; watch the WebKit GPU process.
- Warm open is the tightest speed target (median 172, max 192 of 200 ms).
- If the block list fails to load, show nothing (spec 9.8). The spike
  already refuses to render without it.
- Hand-written Xcode project with folder-synced groups works well: new
  files are picked up without editing the project file. Info.plist
  additions go in a separate file merged with the generated one.
- Release builds need `-destination 'generic/platform=macOS'` to be
  universal. Launch with `open` (not the binary directly) when testing.
- Shell gotchas on this Mac: zsh's own `log` command hides
  `/usr/bin/log`; there's no `timeout` command; zsh doesn't split
  variables into words.

**Spike**
- `spike/` stays in the repo as reference while M1 reuses its pieces
  (web view configuration, block list, scheme handler, timing). Delete it
  once M1 is done.

**Not tested**
- macOS 15 (only 26.6 available). Intel Macs (built for, not run).
- An actual Finder double-click (timed with `open -a`, same path).

**Next**
- Roadmap M1, task 1.1: create the real project layout. Needs a real
  bundle ID (for example based on your GitHub username).

## 2026-11-04: Roadmap 0.5, app size

**Done**
- Archived the spike (`xcodebuild archive`, Release, universal), which
  strips debug symbols the way a real release would.

**Results** (spike: AppKit + WebKit + swift-markdown, two tiny resources)

| What | Size | Target |
|---|---|---|
| Whole `.app`, universal | **2.2 MB** (2,210,978 bytes) | < 5 MB (spec 8.4) |
| Executable, Apple silicon slice | 1.06 MB | |
| Executable, Intel slice | 1.13 MB | |
| Zipped (rough download size) | 0.86 MB | |

- Almost all of it is `swift-markdown` + `swift-cmark`: before the package
  the whole app was 176 KB.
- Code signature still sandbox + user-selected read-only + network.client,
  hardened runtime on.
- Budget left for the real app: about 2.8 MB. The app icon is the main
  unknown (a full icon set can be several hundred KB); our own Swift code,
  CSS and highlighter rules should be small.

**Next**
- Roadmap 0.6: sum up M0 and confirm the ADRs still stand.

## 2026-11-04: Roadmap 0.4, open-to-preview timing

**Done**
- Spike registers as a Markdown viewer (`spike/Info.plist`: document type
  `net.daringfireball.markdown`, role Viewer, rank Alternate, extensions
  md/markdown/mdown/mkd), merged with the generated Info.plist.
- Opening a file (Finder or `open`) reads, parses and renders it off the
  main thread with swift-markdown's built-in `HTMLFormatter` (smart
  punctuation off), shows it in a locked-down web view in its own window,
  and prints a `TIMING` line. Signposts are emitted too (not yet looked at
  in Instruments).
- Timing script (kept in the session scratchpad, not the repo) records
  the moment it runs `open -a Spike.app file.md` and compares it with the
  app's "document loaded" time. Cold = app not running; warm = app
  running, open another file.

**Results** (Release, universal build, macOS 26.6, Apple silicon, 50 KB
file made from this project's docs; 6 cold runs, 18 warm runs)

| | Median | Min | Max | Target |
|---|---|---|---|---|
| Cold (first launch after build) | 430 ms | | | < 500 ms |
| Cold (other 5) | 359 ms | 332 ms | 367 ms | < 500 ms |
| Warm | 172 ms | 142 ms | 192 ms | < 200 ms |

Where a typical cold open goes (ms after process start, run 4):
- `open` → process start: ~20 ms
- process start → `main`: ~80 ms (loading system frameworks)
- `main` → app finished launching (file delivered): ~90 ms
- read + parse + render 50 KB: ~12 ms
- window + web view created: ~35 ms
- web view load → loaded: ~120 ms

**Caveats**
- "Loaded" is WebKit's `didFinish` navigation, a stand-in for first
  paint; real first paint is around the same moment.
- Timed with `open -a`, which uses the same LaunchServices path as a
  Finder double-click, but not an actual double-click.
- The spike renders with the built-in formatter and minimal CSS. The real
  renderer and highlighter will cost more, but parsing + rendering was
  only ~4 ms here, so there's room.
- The spare web view was created too late (after the file arrived) and
  went unused; a cold open with it working should be faster. Noted in
  architecture.md.
- Warm opens sit close to the 200 ms target (max 192 ms); most of that is
  WebKit starting a page for the new web view. Keeping a spare web view
  ready after each open is the obvious fix if it creeps over.

**Next**
- Roadmap 0.5: release build size check.

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
