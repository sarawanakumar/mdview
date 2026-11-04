# Architecture

How mdview is built. [vision.md](vision.md) says why and
[spec.md](spec.md) says what. Each significant choice has its own decision
record (ADR) in [adr/](adr/); this document summarises them and shows how
the pieces fit.

## Decisions at a glance

| ADR | Decision | Status |
|---|---|---|
| [0001](adr/0001-swift-markdown-only-dependency.md) | Apple's `swift-markdown` is the only package dependency | Accepted |
| [0002](adr/0002-appkit-nsdocument.md) | AppKit app built on `NSDocument`, no SwiftUI, no storyboards | Accepted |
| [0003](adr/0003-render-with-wkwebview.md) | Render by turning Markdown into HTML and showing it in `WKWebView`, with JavaScript off | Accepted |
| [0004](adr/0004-in-project-code-highlighter.md) | Small hand-written highlighter, run in Swift while building the HTML | Accepted |
| [0005](adr/0005-sandbox-and-file-access.md) | App Sandbox on; local files served to the page through a custom URL scheme; one-time folder access grants | Accepted (point 1 changed by 0006) |
| [0006](adr/0006-outgoing-network-entitlement-for-webkit.md) | Grant the outgoing-network entitlement, because WebKit can't run in the sandbox without it; offline is enforced by the layers below | Accepted |

## Technology

- **Language:** Swift 6, with strict concurrency checking.
- **Tooling:** Xcode 16 or later. No other build tools.
- **Minimum OS:** macOS 15 Sequoia, Apple silicon and Intel.
- **Frameworks:** AppKit, WebKit (`WKWebView`), Foundation, UniformTypeIdentifiers.
- **Package:** `swift-markdown` (Apple), pinned to an exact version.

## Shape of the code

Two parts, so the Markdown-to-HTML logic can be tested without launching an
app:

```
mdview.xcodeproj
App/                        the macOS app target (AppKit)
  AppDelegate               launch, menus, "open panel when nothing is open"
  MarkdownDocument          NSDocument subclass: reads the file, read-only
  DocumentWindowController  one window per file; owns the preview and find bar
  PreviewController         wraps WKWebView: loads HTML, reload, zoom, print, find
  AssetSchemeHandler        serves local images and files to the page (ADR 0005)
  LinkRouter                decides what a clicked link does (spec section 4)
  FileWatcher               notices when the file changes on disk (spec section 5)
  EditorLauncher            "Open in Editor" and the remembered editor (spec 6.10–6.12)
  FolderAccess              stores and restores folder access grants (ADR 0005)
  Resources/                preview.css, Info.plist, entitlements, app icon
Packages/MDViewCore/        local Swift package, no AppKit
  FrontMatter               strips a leading YAML block (spec 2.13)
  HTMLRenderer              swift-markdown tree → HTML string
  HeadingSlugger            GitHub-style heading anchors (spec 4.3)
  Highlighter/              tokenizer + one small rule set per language (ADR 0004)
  Tests/                    unit tests, run with `swift test`
fixtures/                   the test Markdown files listed in spec.md
```

Everything that knows about Markdown lives in `MDViewCore`. The app target
only knows about windows, files and the web view.

## How a file gets on screen

```
Finder double-click / Cmd+O
        │
        ▼
NSDocumentController ──(already open?)──► bring window to front
        │ new
        ▼
MarkdownDocument.read(from:)          read bytes, decode UTF-8 (replace bad bytes)
        │
        ▼
MDViewCore.render(text, baseName)     strip front matter
        │                             parse with swift-markdown
        │                             walk the tree → HTML, highlighting code blocks
        ▼
PreviewController.show(html)          wrap in a page shell with preview.css
        │                             loadHTMLString(base: mdview-file://<doc folder>/)
        ▼
WKWebView                             images requested via mdview-file:// →
                                      AssetSchemeHandler reads them from disk
```

### Rendering details

- **Parsing.** `swift-markdown` with its GitHub-flavored extensions (tables,
  strikethrough, task lists), and with smart punctuation turned off
  (`.disableSmartOpts`) so text shows as written (spec 2.15). The tree is walked by our own `MarkupVisitor`
  rather than the package's built-in HTML formatter, because we need
  heading anchors, code highlighting, image placeholders and HTML escaping.
- **Front matter** must be removed before parsing: `swift-markdown` would
  otherwise read it as a horizontal rule followed by a heading (roadmap
  0.2).
- **Bare web addresses.** `swift-markdown` doesn't link them, so the
  renderer scans plain text nodes (never code) for `http://`, `https://`
  and `www.` addresses and wraps them in links, leaving trailing
  punctuation outside, following GitHub's rules (spec 2.14).
- **Inline HTML** in the source is escaped and shown as text (spec 2.12).
- **Page shell.** The CSS is bundled in the app and inlined into each page,
  so nothing is fetched. It uses system fonts (`-apple-system`,
  `ui-monospace`), a centred ~80-character column, and
  `prefers-color-scheme` for light/dark (spec 6.3, 6.4).
- **Wide content.** Code blocks and tables sit in their own
  `overflow-x: auto` boxes, so they scroll sideways on their own (spec 2.8,
  2.9).
- **Images.** Relative and `file://` paths are rewritten to `mdview-file://`
  URLs. Remote images become a placeholder showing the alt text (spec 3.5).
  The renderer is given a "does this file exist and can I read it?" check
  by the app, and missing or unreadable images get the same placeholder
  (spec 3.6). This is done while building the HTML, because with JavaScript
  off the page can't react to a failed image load itself.
- **Link tooltips.** Each link gets a `title` attribute with its destination
  (spec 4.5).

### Safety settings on the web view

- Page JavaScript disabled (`allowsContentJavaScript = false`). The app can
  still run its own small scripts (for scroll position and find), but
  nothing in a Markdown file can.
- A `WKContentRuleList` blocks every load except `mdview-file:`, as a
  second layer behind the HTML renderer never emitting remote URLs. Since
  the app has the outgoing-network entitlement (ADR 0006), this list is
  the main barrier: if it fails to compile or install, the document is not
  shown (spec 9.8).
- Non-persistent website data store: no cookies, cache or storage on disk.

## Links

`LinkRouter` is the web view's navigation delegate. Every click is
cancelled and handled in Swift:

| Link | Action |
|---|---|
| `#anchor` | Scroll within the page |
| Relative or `file://` path to a Markdown file | Open it in mdview through `NSDocumentController`, then scroll to `#anchor` if there is one |
| Other local file | `NSWorkspace.open` (its default app) |
| `http`, `https`, `mailto` | `NSWorkspace.open` (browser, mail) |
| Missing file | Brief "File not found" message in the window |

## Automatic reload

- `FileWatcher` uses a `DispatchSource` on the open file for write, delete
  and rename events. Many editors save by writing a new file and renaming it
  over the old one, so on delete/rename it waits briefly, then reopens the
  path and watches the new file (spec 5.3).
- Events are debounced (~50 ms) so one save causes one reload.
- On reload, the new HTML body is swapped into the existing page with a
  small app-side script instead of reloading the page. That keeps the scroll
  position (spec 5.2) and is faster than a full load.
- Image URLs get a changing query value on each reload, so changed images
  refresh (spec 5.5).
- If the file is gone, the window keeps the last content and shows a notice;
  the watcher keeps checking for it to come back (spec 5.4).

## Windows, menus and system features

`NSDocument` gives us, with little code: one window per file, opening an
already-open file brings it forward, Open Recent, window tabs, the title
bar path menu, state restoration, and the open panel at launch (spec 1, 6).
The document is read-only: no saving, no autosave, no "edited" dot.

| Spec | How |
|---|---|
| Find (6.6) | A slim find bar at the top of the window (search field, next/previous, match count) driving `WKWebView.find(_:configuration:)`. WebKit doesn't provide AppKit's standard find bar, so this is ours, styled to match it. |
| Zoom (6.7) | `WKWebView.pageZoom`, per window |
| Print (6.8) | `WKWebView.printOperation(with:)` with the standard print panel |
| Reveal in Finder (6.9) | `NSWorkspace.activateFileViewerSelecting` |
| Open in Editor (6.10–6.12) | Remembered app URL in `UserDefaults`; `NSWorkspace.open(_:withApplicationAt:)`. Picker is an `NSOpenPanel` limited to applications. |
| VoiceOver (6.14) | Comes from WebKit reading proper HTML headings, links and image alt text |

## Code highlighting

See [ADR 0004](adr/0004-in-project-code-highlighter.md). In short: while
building HTML, each fenced block with a known language tag is run through a
tokenizer that marks keywords, strings, comments and numbers with
`<span class="tok-…">`. Colours for each class live in `preview.css`, with
separate light and dark values. Unknown tags are escaped and left plain.

## Performance plan

The targets are in spec section 8. The main risk is the web view's start-up
cost on a cold launch.

- **Start the web view early.** At launch, create the shared
  `WKWebViewConfiguration` and one hidden web view, so WebKit's helper
  process starts while the file is being read and parsed. The spare must
  be created *before* the first file arrives (in
  `applicationWillFinishLaunching`), and a new spare made after each use;
  the spike created it too late, so it went unused (roadmap 0.4).
- **Do the work off the main thread.** Reading, parsing and HTML building
  run on a background task; only the final `loadHTMLString` touches the UI.
- **Show text first.** Images load after the page is shown (spec 3.7).
- **Measure.** Points of interest are marked with `os_signpost` (launch,
  file read, parse done, HTML done, first paint), so Instruments shows where
  time goes. A small script times "double-click to first paint" on the
  fixture files.

## Testing

- **MDViewCore unit tests** (`swift test`): for each fixture, the generated
  HTML is compared with a stored expected file. Also front matter,
  slugs, escaping, and each highlighter language, including malformed input
  (spec 7.6, 10.4).
- **Fuzz-style test**: random and truncated Markdown is rendered in a loop
  to check nothing crashes or hangs.
- **App checks**: a written checklist in `fixtures/` covering spec sections
  1, 4, 5 and 6 that need a real window, run before each release.
- **Performance**: the timing script above, against spec section 8.

## Risks to check first

Before building features, a short spike should confirm the choices that
the rest depends on:

1. **Cold open time with `WKWebView`.** Is "double-click to first paint"
   under 0.5 s on the development Mac? If not, ADR 0003 is revisited.
   *Result (0.4): yes. Cold median 359 ms, warm median 172 ms for a 50 KB
   file (details in progress.md).*
2. **Sandbox and networking.** `WKWebView` in a sandboxed app without the
   network entitlement shows local HTML and custom-scheme images correctly.
   *Result (0.3): it doesn't; WebKit needs the outgoing-network
   entitlement. Resolved by ADR 0006.*
3. **`swift-markdown` coverage.** Tables, task lists and strikethrough parse
   as expected; check whether footnotes are supported (spec open question).
   *Result (0.2): all required elements parse; no footnotes (out of
   scope).*
4. **Bundle size** with `swift-markdown` linked in stays under 5 MB.
   *Result (0.5): 2.2 MB universal, archived and stripped.*

## Still open

- **Distribution.** Build from source only, or a signed and notarised
  release on GitHub (notarising needs a paid Apple Developer account).
  Doesn't affect the code; decide before the first release.
