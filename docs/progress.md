# Progress

Newest session first.

## 2026-11-04: Roadmap 2.7, front matter, links, bare web addresses

**Done**
- `MDViewCore/FrontMatter`: removes a block from a `---` first line to
  the next `---` or `...` line. Unclosed blocks, blocks not on line 1 and
  `----` are left alone; later `---` lines are untouched. Works with
  `\n`, `\r\n` and `\r` (first version split on `\n` only, which
  missed Windows line endings because Swift treats `\r\n` as one
  character; caught by a test).
- Links now render as `<a href title>` (spec 2.11). `title` is the
  destination, so hovering shows where it goes (spec 4.5; spec updated:
  a Markdown link title isn't shown). Only relative paths, `#anchors`,
  and http, https, mailto and file URLs get an `href`; anything else
  (`javascript:`, `data:`, `vbscript:`, `ftp:`) keeps only its text.
  Clicks are still cancelled by the app until roadmap 3.5.
- `MDViewCore/Autolinker`: GFM extended autolinks for `http://`,
  `https://` and `www.` (spec 2.14): must start at the start, after a
  space or `* _ ~ (`; valid domain (a `.`, no `_` in the last two parts);
  trailing `? ! . , : * _ ~ ' "`, unmatched `)` and `&entity;` dropped;
  `www.` gets `http://`. Not inside links, images or code.
- Smart punctuation was already off (2.2); 2.15 passes.
- `preview.css`: links in the system link colour, underlined on hover.

**Checked**
- 124 tests pass (27 new): front matter cases incl. CRLF; link kinds,
  safe and unsafe destinations, escaping; autolink trailing-character
  cases (incl. Wikipedia-style parentheses, ports, queries), non-links
  (`localhost`, underscores in the domain, email, a quote right before),
  uppercase scheme, accented domain, not in code or link text.
- `front-matter.md` and the links / bare address / punctuation sections
  of `elements.md` read through: correct.
- App builds with no warnings. Not checked visually.

**Speed** (release build, render only, 5 MB generated files)
- First version: 1,268 ms for a link-heavy file. Breakdown: parsing
  436 ms (swift-markdown), building HTML 776 ms, of which the bare-address
  scan 286 ms and an "inside a link?" check that walked up the tree for
  each of 242,000 text pieces (slow in swift-markdown).
- Fixed both: link depth is counted while walking, and a quick byte check
  skips text with no "ht"/"ww". Now 1,133 ms link-heavy (every paragraph
  has links, a table in every section), 152 ms for 5 MB of plain prose.
- Spec 8.3 (5 MB opens in < 2 s) still needs an end-to-end measurement
  including WebKit layout; that's roadmap 7.2. The link-heavy worst case
  may need more work there.

**Next**
- Roadmap 2.8: complete `preview.css`.

## 2026-11-04: Roadmap 2.6, code blocks and tables

**Done**
- Code blocks: `<pre><code class="language-x">`, code escaped, final
  newline trimmed, blank lines inside kept. The language is the info
  string's first word, lowercased, filtered to letters, digits and
  `+-_#.` so it's safe as a class (M6 hooks highlighting in here).
  Fenced (backtick and tilde) and indented blocks.
- Tables: `<div class="table"><table>` with `<thead>` / `<tbody>`;
  alignment as `align-left|center|right` classes (no inline styles);
  short rows padded with empty cells and extra cells dropped, as on
  GitHub; colspan/rowspan passed through if present.
- Every block is now rendered: the temporary "shown as source" path and
  its styles are gone.
- `preview.css`: code block box that scrolls sideways; tables with
  borders, bold header, striped rows; tables keep their natural width so
  a wide one scrolls inside its own box (spec 2.9).

**Checked**
- 97 tests pass (18 new: fences, indented code, escaping, blank lines,
  empty block, info string, safe language names incl. `"><script>`,
  code in quotes and list items; tables: structure, alignment,
  formatting in cells, escaped pipe, padding, dropping, header only,
  escaping).
- `elements.md` read through: code blocks and both tables correct, code
  and a table inside list items correct, nothing left as source.
- App builds with no warnings. Not checked visually (wide table and long
  code line scrolling in particular).

**Memory re-check** (one file open plus the 9 MB spare; each process's
footprint added up after 12 s; two runs each)

| File | Total | Page process |
|---|---|---|
| typical.md (lists, tables, code heavy) | 105–114 MB | 49 MB (61 MB with the old source boxes) |
| elements.md | 84–104 MB | 27–37 MB |
| prose.md | 76–90 MB | 23–35 MB |

- `typical.md` is still slightly over the 100 MB target (spec 8.5);
  without the spare it would be about 96–105 MB. Readings vary 10–20 MB
  run to run on this busy machine.
- An earlier reading taken after 5 s showed 234 MB: WebKit's GPU process
  still at its start-up peak (~135 MB). Measuring method now noted in
  roadmap 7.2 (wait ≥ 10 s, add up per process, several runs).

**Next**
- Roadmap 2.7: strip front matter, link bare web addresses (smart
  punctuation is already off).

## 2026-11-04: Roadmap 2.5, blockquotes

**Done**
- `<blockquote>` holding any blocks: paragraphs, headings, lists, other
  quotes. Code blocks inside quotes are still shown as source until 2.6.
- `preview.css`: GitHub-style quotes (left bar, muted text, no extra
  space at the top and bottom).

**Checked**
- 79 tests pass (10 new: simple, lazy continuation, two paragraphs, a
  blank line ending the quote, 3 levels, list inside, quote inside a list
  item, heading and formatting inside, HTML inside still text, empty
  quote).
- `elements.md` quotes read through: 3 levels nested correctly, list
  inside the outer quote, quote inside a numbered item.
- App builds with no warnings. Not checked visually.

**Next**
- Roadmap 2.6: code blocks (plain for now) and tables.

## 2026-11-04: Roadmap 2.4, lists and task lists

**Done**
- `<ul>` / `<ol>` with `start="N"` when a list doesn't start at 1;
  nested lists inside their item.
- Task items: `<li class="task-list-item"><input type="checkbox" disabled
  [checked]>`, list gets `class="contains-task-list"`. `[ ]`, `[x]`, `[X]`;
  read-only (spec 2.5); VoiceOver reads the box as checked or not.
- **Tight vs loose lists**, as CommonMark and GitHub do: in a tight list
  an item's paragraph is just its text; in a loose one it stays a `<p>`.
  swift-markdown doesn't report this, so `isTight` works it out from
  source lines. Found while doing it: item, list and quote ranges include
  trailing blank lines, so the check follows the last block inside down
  to a block whose range is exact. Without that, a blank line after a
  nested list was missed.
- `preview.css`: list indents and spacing like GitHub, nested numbered
  lists as i, ii, iii then a, b, c; task items have no bullet.
- Fixture fix: `elements.md`'s "starts at seven" list directly followed
  the numbered list, so Markdown (and GitHub) merged them into one list.
  Added a sentence between them so the start number is really tested.

**Checked**
- 69 tests pass (18 new: 3 bullet kinds, numbering, start numbers incl.
  0, 4-level nesting, mixed nesting, formatting, loose/tight rules incl.
  per-list tightness, escaping, task lists open/done/capital X/mixed/
  numbered/nested, `[x]` mid-text not a checkbox).
- `elements.md` output read through for lists and task lists: correct.
- App builds with no warnings. Not checked visually.

**Next**
- Roadmap 2.5: blockquotes.

## 2026-11-04: Roadmap 2.3, heading anchors

**Done**
- `MDViewCore/HeadingSlugger`: GitHub's `github-slugger` rules. Lowercase;
  keep letters, marks, numbers, `-`, `_` in any script; each space
  becomes `-` (not merged); drop punctuation, symbols and emoji; repeats
  get `-1`, `-2`, … skipping names already used. One per document.
- Headings render as `<hN id="slug">`. The slug comes from the text a
  reader sees (formatting removed, inline code without backticks, link
  text included). A heading with no usable characters gets no `id`.

**Checked**
- 51 tests pass. Slug cases include `Tables (2.9)` → `tables-29`,
  `Punctuation: "quotes", & ampersands, (brackets)!` →
  `punctuation-quotes--ampersands-brackets`, accents, Japanese, emoji,
  `C++ & C#` → `c--c`, `v1.2.3` → `v123`, numbering that skips a name
  already taken (`Foo 1`, `Foo`, `Foo`, `Foo` → `foo-1`, `foo`, `foo-2`,
  `foo-3`), and that quotes can't break out of the attribute.
- `elements.md`: 31 headings, all IDs unique, duplicates numbered,
  `tables-29` exists for the file's own `#tables-29` link.
- App builds with no warnings.
- Not checked against GitHub itself (no network use); the expected
  slugs are from GitHub's documented rules and known examples.

**Next**
- Roadmap 2.4: lists, nested lists, start numbers, task lists.

## 2026-11-04: Roadmap 2.2, inline elements and rules

**Done**
- `HTMLRenderer` rebuilt as a swift-markdown `MarkupVisitor`
  (`HTMLVisitor`). Renders headings, paragraphs, soft breaks (kept as a
  newline, shown as a space), hard breaks (`<br>`, from two spaces or a
  backslash), `<em>`, `<strong>`, `<del>` (`~~` and `~`), `<code>`,
  `<hr>`. Inline HTML is escaped into the text; an HTML block becomes
  `<pre class="html-source">` with its source escaped (spec 2.12).
  Entities are decoded by the parser, then escaped. Links and images
  show their text for now; lists, quotes, code blocks and tables are
  still escaped source until 2.4–2.6.
- Tests rewritten as one suite per criterion: 41 tests in 12 suites,
  including a check that no `<img>`, `<iframe>`, `<style>` or `<script>`
  from the source ever survives.
- `preview.css`: inline code, rules, and muted HTML source.

**Checked**
- 41 tests pass. Recorded `elements.md`'s HTML once to read it (then
  deleted it): every 2.2 element renders as intended, and the only tags
  in the output are mdview's own.
- Noticed in that output: a line in `elements.md` that starts with
  `<script>` becomes an HTML block, not part of the paragraph above. That
  is correct CommonMark (such tags can end a paragraph), and it's still
  shown only as text.
- App builds with no warnings and opens `elements.md` (read and visible
  signposts). Not visually checked.

**Next**
- Roadmap 2.3: headings with GitHub-style anchors.

## 2026-11-04: Roadmap 2.1, M2 test files and expected-HTML tests

**Done**
- Removed `spike/` (planned once M1 was done; it stays in git history).
  Nothing in the app used it.
- `fixtures/elements.md`: every spec section 2 element, each section
  labelled with its criterion. Covers ATX and setext headings, duplicate
  and punctuated headings (for anchors), soft/hard/backslash breaks, all
  emphasis forms and non-emphasis cases, lists (3 bullet kinds, 4 levels,
  start number, loose items), task lists (nested, capital X), quotes (3
  levels, with list and code), inline code with backticks, fenced (with
  and without language, tilde), indented and very long code, tables
  (alignment, inline formatting, escaped pipe, empty cells, a very wide
  one), 3 kinds of rule, inline/titled/reference/autolinks, relative and
  anchor links, bare web addresses with trailing punctuation, punctuation
  as written, a local and a remote image, inline and block HTML,
  escapes, entities, and lists containing quotes, code and tables.
- `fixtures/front-matter.md`: front matter, a later `---` rule, and a
  setext heading whose underline is `---`.
- `fixtures/images/sample.png` (48×48) for the local image.
- `Tests/MDViewCoreTests/FixtureTests.swift`: finds every `.md`/`.txt`
  under `fixtures/` (except `expected/`); checks each renders without
  crashing (spec 10.4) and, where `fixtures/expected/<name>.html` exists,
  matches it exactly. `MDVIEW_RECORD_EXPECTED=1` writes the expected
  files. `fixtures/expected/README.md` explains this.
- Roadmap: added **2.10**, review the fixtures in the app, then record the
  expected HTML and re-measure memory. Recording now would only capture
  the temporary minimal renderer's output.

**Checked**
- 23 tests pass (6 fixtures × 2 tests, plus a check that the fixtures
  folder is found).
- Record mode wrote 6 expected files; comparison then passed; changing
  one made the test fail with "elements.md differs from elements.html".
  Recorded files deleted afterwards.

**Next**
- Roadmap 2.2: paragraphs, line breaks, emphasis, strikethrough, inline
  code, rules, with HTML escaping.

## 2026-11-04: Roadmap 1.7, early web view start, signposts, timings

**Done**
- `App/Signposts.swift`: points-of-interest events appLaunched,
  launchFinished, previewReady, spareReady, documentRead,
  documentRendered, documentVisible (only for the document's own page,
  not a spare's blank page).
- `PreviewConfiguration`: once the configuration is ready, one spare web
  view with a blank page loaded. A document takes it; 0.5 s later a new
  spare is made. Never more than one.
- Timing script (session scratchpad) now reads the signposts with
  `log show --signpost`, launches with `-ApplePersistenceIgnoreState YES`
  so restored windows don't interfere, and uses a different file for each
  warm open (an already-open file is only brought forward).

**Results** (Release, macOS 26.6, Apple silicon, 50 KB file. The machine
was busy: load average 7–9. As a control, the spike re-measured under the
same load: cold 418 ms, warm 182 ms, against 359 / 172 earlier.)

| Variant | Cold median | Warm median (max) |
|---|---|---|
| No spare | 464 ms | 217 ms (236) |
| Spare at launch only | 453–469 ms | 201–214 ms (245) |
| **Spare at launch + refilled (kept)** | **479 ms** | **159 ms (178)** |

- Spec 8.2 (warm < 200 ms) passes with the refilled spare, and every warm
  run was under 200 ms. Without it, warm opens missed the target.
- Spec 8.1 (cold < 500 ms) passes, but only just under this load (one run
  hit exactly 500 ms). First launch after a rebuild was 1,197 ms (macOS
  checking the new signature), as expected.
- Typical cold run: appLaunched ~140 ms after `open`, launchFinished
  ~260, documentRead ~270, previewReady ~310, spareReady ~360,
  documentRendered ~375, documentVisible ~470. The file is read before
  WebKit's setup is ready, so the block list lookup is on the critical
  path; creating the spare also holds the main thread ~50 ms just when
  the first file arrives. Candidates for roadmap 7.2.

**Memory** (one file open, one spare waiting)

| File | Total | Page process |
|---|---|---|
| prose.md (50 KB, headings and paragraphs only) | 93 MB | 35 MB + 9 MB spare |
| typical.md (50 KB, many lists/tables/code) | **120 MB** | 61 MB + 9 MB spare |

- On prose, mdview matches the spike exactly (page process 35 MB each).
- typical.md is over the 100 MB target (spec 8.5). Bisected: not the
  spare, not the stylesheet, not the scrollable boxes, not the fonts. It
  comes from the minimal renderer showing hundreds of lines of lists,
  tables and code as source boxes. M2 replaces that, so re-measure then;
  if real code blocks and tables cost the same, memory needs work.

**Next**
- Roadmap M2, task 2.1: test files and expected-HTML tests.

## 2026-11-04: Roadmap 1.6, several files, reopening, errors

**Done**
- Windows now cascade (each new one 29 px down and right of the last)
  instead of all being centred on top of each other. That was the only
  code change: the rest of 1.6 comes from `NSDocumentController`.

**Checked** (temporary in-app window dump, removed afterwards)

| Spec | Test | Result |
|---|---|---|
| 1.4 | Open 3 files in one request (as selecting 3 in Finder) | 3 documents, 3 windows, cascaded |
| 1.5 | Open a 4th file while running (`open -a`, the same open-document request a Dock drop sends) | 4th window opens in front |
| 1.6 | Open `valid.md` again | Still 4 documents; its window comes to the front |
| 1.6 | Open it through a symlink | Still 4 documents (recognised as the same file) |
| 10.3 | Open a permission-denied file (the call Open Recent uses) | "The document “locked.md” could not be opened. You don’t have permission." No window left behind |
| 10.3 | Open a file that doesn't exist | "…could not be opened. The file doesn’t exist." Standard modal alert on screen (260×208), no window left behind |

- Debug and Release build with no warnings; 20 core tests pass.

**Found**
- An unreadable file can't reach mdview from Finder or `open`: macOS
  refuses it first (error -5000). So in practice 10.3 is about files that
  vanish or become unreadable before mdview reads them, such as Open
  Recent entries.
- After a force quit, macOS restored the previous windows on the next
  launch, even when launched to open another file (spec 6.13 behaviour,
  for free). Still to check in 5.6: launching on its own with restored
  windows shouldn't also show the Open panel.
- Not tested: an actual drag onto the Dock icon (no pointer control).

**Next**
- Roadmap 1.7: early web view start and signposts; record cold and warm
  times.

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
