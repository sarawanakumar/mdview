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
  AppDelegate               launch, "open panel when nothing is open"
  MainMenu                  the menu bar, built in code
  RecentDocumentsMenu       fills File → Open Recent (spec 1.7)
  MarkdownDocumentController  opens every file as a MarkdownDocument (spec 10.5)
  MarkdownDocument          NSDocument subclass: reads the file, read-only
  DocumentWindowController  one window per file; owns the preview and find bar
  FindBar                   the find bar (spec 6.6)
  PreviewConfiguration      the shared locked-down web view setup (block list, JS off),
                            plus the one spare web view
  Signposts                 timing points for Instruments
  PreviewController         wraps WKWebView: loads HTML, reload, zoom, print, find
                            (PageShell: wraps the body with CSS and a security policy)
  AssetSchemeHandler        serves local images to the page (ADR 0005); ImageAccess
                            decides which may be shown and builds their URLs
  (links)                   PreviewController passes clicks to DocumentWindowController,
                            which carries out LinkRoute's decision (spec section 4)
  EditorLauncher            "Open in Editor" and the remembered editor (spec 6.10–6.12)
  FolderAccess              stores and restores folder access grants (ADR 0005)
  mdview.entitlements       sandbox, user-selected read-only, app-scoped bookmarks,
                            outgoing network
  Resources/                preview.css, Info.plist, app icon
Packages/MDViewCore/        local Swift package, no AppKit
  UTF8Text                  bytes → text, bad bytes replaced and reported (spec 10.2)
  FrontMatter               strips a leading YAML block (spec 2.13)
  Autolinker                finds bare web addresses, GitHub's rules (spec 2.14)
  NestingGuard              spots files nested too deeply to parse safely (spec 10.4)
  ZoomLevels                zoom steps (spec 6.7)
  PageSecurity              block list, security policy and scheme name (ADR 0006)
  HTMLEscaping              escapes text for HTML
  HTMLRenderer              swift-markdown tree → HTML string
  HeadingSlugger            GitHub-style heading anchors (spec 4.3)
  Highlighter/              Highlighter (the scanner) + LanguageRules (one small
                            table per language, roadmap 6.2–6.3) (ADR 0004)
  Files/FolderGrantList     which folders are granted (pure path rules, spec 9.6)
  Files/LocalReferences     resolves a page's local references; suggests a folder
  Files/LinkRoute           decides what a clicked link does (spec 4.1–4.4)
  Files/FileWatcher         notices when a file changes on disk (spec section 5)
  Tests/                    unit tests, run with `swift test`
fixtures/                   the test Markdown files listed in spec.md
scripts/time-open.swift     times opening files against spec section 8
```

Everything that knows about Markdown lives in `MDViewCore`, along with any
other logic that doesn't need AppKit or WebKit (such as the folder-grant
rules), so it can be unit tested. The app target only knows about windows,
files, bookmarks and the web view.

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
- **Images.** The renderer asks an `ImageLocator` (supplied by the app)
  for each local image. The app's locator resolves the source against the
  document and returns `mdview-file://document/<absolute path>` only for
  an image file that exists inside a granted folder; it uses a snapshot of
  the grants, so it's safe on the render thread. Everything else (missing,
  not granted, remote, unsafe) becomes a placeholder showing the alt text
  (spec 3.5, 3.6). This is decided while building the HTML, because with
  JavaScript off the page can't react to a failed image load itself. The
  scheme handler checks the same rules again before serving a file, reads
  it off the main thread, and ignores requests WebKit has cancelled.
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
- Each page carries a Content Security Policy (`default-src 'none'`,
  images only from `mdview-file:`, inline styles only): one more layer
  that blocks scripts and remote loads even if the others failed.
- Navigation: only our own page load is allowed; clicked links are
  cancelled until `LinkRouter` (roadmap 3.5).

## Links

Each page's base URL is `mdview-file://document/<document's folder>/`
(symlinks resolved), so WebKit resolves relative links, `../` included,
into real file paths.

`PreviewController` is the web view's navigation delegate. Only a real
link click (`linkActivated`) is routed; any other navigation is allowed
only if it's our own page load (this page's base URL, or a spare's blank
page), and cancelled otherwise. `LinkRoute` (MDViewCore) decides; the
document window carries it out:

| Link | Action |
|---|---|
| `#anchor` on this page | Allowed: WebKit scrolls to it |
| Another Markdown file (`.md`, `.markdown`, `.mdown`, `.mkd`) | Open it in mdview through `NSDocumentController`, then scroll to `#anchor` if there is one (app script, id passed as an argument) |
| Other local file or folder | `NSWorkspace.open` (its default app) |
| `http`, `https`, `mailto` | `NSWorkspace.open` (browser, mail) |
| A local file outside granted folders | Folder picker first; carried out if the grant covers it |
| Missing file | Brief "“name” wasn't found." notice, announced to VoiceOver |
| Anything else | Nothing |

Cmd-click and `target="_blank"` links come through `createWebViewWith`
and are routed the same way; no new web view is made.

## Automatic reload

- `FileWatcher` (MDViewCore, no AppKit, unit tested with real files) uses
  a `DispatchSource` on the open file for write, extend, delete, rename,
  revoke and link events. Many editors save by writing a new file and
  renaming it over the old one, so on delete/rename it looks for a file at
  the path again every 50 ms (up to 1 s) and watches that (spec 5.3). If
  none appears it reports the file gone, then checks once a second for it
  to come back (spec 5.4).
- Events are debounced (50 ms) so one save causes one reload.
- Each `MarkdownDocument` owns a watcher (started with its window, stopped
  on close). A change re-reads the file with `revert(toContentsOf:)` and
  tells its window to render again.
- On reload, the new HTML body is swapped into the existing page with a
  small app-side script (`document.body.innerHTML`, the HTML passed as an
  argument) instead of reloading the page. That keeps the scroll position
  (spec 5.2) and is faster than a full load. Renders are numbered so an
  older one never replaces a newer one; if the swap fails, the page is
  loaded normally.
- Image URLs carry the image file's modification time (`?v=`), so a
  changed image gets a new URL and is fetched again, while unchanged ones
  stay cached (spec 5.5).
- If the file is gone (deleted, or moved away, including to the Trash),
  the window keeps the last content and shows a notice that stays until
  the file is back; the watcher keeps checking once a second (spec 5.4).
  A moved file is not followed to its new name: AppKit didn't follow a
  coordinated move here, and the spec treats "moved away" as gone.

## Windows, menus and system features

`NSDocument` gives us, with little code: one window per file, opening an
already-open file brings it forward, Open Recent, window tabs, the title
bar path menu, state restoration, and the open panel at launch (spec 1, 6).
The document is read-only: no saving, no autosave, no "edited" dot.

| Spec | How |
|---|---|
| Find (6.6) | `FindBar`: a slim bar at the top of the window (search field, previous/next, match count, Done) driving `WKWebView.find(_:configuration:)`, case-insensitive and wrapping. Typing searches from the top; Return / Shift-Return step; Esc closes. Edit ▸ Find: Find… ⌘F, Find Next ⌘G, Find Previous ⇧⌘G, Use Selection for Find ⌘E, handled by the document window. The match count and selected text come from the app's own script (search text passed as an argument). WebKit doesn't provide AppKit's standard find bar, so this is ours. |
| Zoom (6.7) | `WKWebView.pageZoom`, per window, in Safari's steps (`ZoomLevels`, MDViewCore: 50–300 %). View menu: Actual Size ⌘0, Zoom In ⌘= (and ⌘+), Zoom Out ⌘−, greyed out when they'd do nothing. Kept when the page re-renders; not remembered after the window closes. |
| Print (6.8) | File ▸ Page Setup… ⇧⌘P and Print… ⌘P, handled by `NSDocument`. `MarkdownDocument.printOperation(withSettings:)` returns `WKWebView.printOperation(with:)` (its view given the web view's size, or WebKit prints blank pages), fitted to the page width. The standard print panel includes Save as PDF. Print styles in `preview.css` make it black on white at full width, even in dark mode. |
| Reveal in Finder (6.9) | File ▸ Reveal in Finder ⇧⌘R → `NSWorkspace.activateFileViewerSelecting`; greyed out while the file is gone (spec 5.4) |
| Open in Editor (6.10–6.12) | `EditorLauncher`: the chosen app saved as a bookmark in `UserDefaults` (survives the app being moved; forgotten if it's gone, so the picker returns). `NSWorkspace.open(_:withApplicationAt:)`. Picker: an `NSOpenPanel` sheet limited to applications, starting in /Applications; choosing MDView itself is refused. File ▸ Open in Editor… ⇧⌘E (titled "Open in TextEdit" etc. once chosen) and Change Editor… |
| Keyboard (6.14) | The page gets focus when it first appears (unless the find field has it), so arrows, Space and Page keys scroll at once. `tabFocusesLinks` is on: Tab / Shift-Tab move through links and Return follows one. Every command has a menu item and most a shortcut. |
| VoiceOver (6.14) | Comes from WebKit reading proper HTML: `<h1>`–`<h6>`, `<a href>`, `<img alt>` or a placeholder with `role="img"` and `aria-label`, `<input type="checkbox" disabled [checked]>`, tables with `<th>`, `lang="en"`. Notices are announced. |

## Code highlighting

See [ADR 0004](adr/0004-in-project-code-highlighter.md). In short: while
building HTML, each fenced block with a known language tag is run through a
tokenizer that marks keywords, strings, comments and numbers with
`<span class="tok-…">`. Colours for each class live in `preview.css`, with
separate light and dark values. Unknown tags are escaped and left plain.

## Performance plan

The targets are in spec section 8. The main risk is the web view's start-up
cost on a cold launch.

- **Start the web view early.** In `applicationWillFinishLaunching`,
  start building the shared `WKWebViewConfiguration`; once it's ready,
  make one spare web view with a blank page loaded, so WebKit's page
  process is already running. A document takes the spare; half a second
  later a new spare is made, so the next file opens fast too. Never more
  than one spare: a waiting spare costs about 9 MB (roadmap 1.7).
  The block list lookup starts there too, with WebKit's callback API: a
  task wouldn't run until AppKit finishes launching, about 85 ms later
  (roadmap 7.2).
- **Signposts** (`App/Signposts.swift`, points of interest): appLaunched,
  launchFinished, previewReady, spareReady, documentRead,
  documentRendered, documentVisible. Readable in Instruments or with
  `log show --signpost`.
- **Do the work off the main thread.** Reading, parsing and HTML building
  run in the background; only the final `loadHTMLString` touches the UI.
  Rendering starts before the window is built, so the two overlap.
  Markdown is rendered on its own thread with a 64 MB stack
  (`HTMLRenderer.renderSafely`): swift-markdown parses nesting by
  recursion and overflows the 512 KB stack Swift tasks run on at about
  1,000 levels. Files estimated deeper than 1,000 levels are shown as
  plain text with a notice (roadmap 2.9).
- **Show text first.** Images load after the page is shown (spec 3.7).
- **Measure.** Points of interest are marked with `os_signpost` (launch,
  file read, parse done, HTML done, first paint), so Instruments shows where
  time goes. `scripts/time-open.swift` times "open the file → text
  visible" (the documentVisible signpost) for cold, warm and large opens.
  It's a Swift script, so it needs nothing beyond Xcode.

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
