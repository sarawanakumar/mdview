# Roadmap

The order in which mdview gets built. Each milestone ends with something
that runs and can be checked. Tasks are sized to fit roughly one working
session and are done in order unless noted. Each one lists the spec
criteria (AC) or ADR it delivers.

Tick a task (`[x]`) when its criteria pass, and note it in
[progress.md](progress.md).

---

## M0. Spike: prove the risky choices (done 2026-11-04)

A throwaway app to check the four risks in
[architecture.md](architecture.md#risks-to-check-first) before real work
starts. Nothing from here has to survive, but whatever does can be reused.

- [x] **0.1** Set up git and the Xcode project: AppKit app target,
      sandbox on with no network permission, Swift 6, macOS 15 minimum.
- [x] **0.2** Add `swift-markdown` pinned to an exact version. Parse a
      sample file and print the tree. Check tables, task lists,
      strikethrough and footnotes. *(Spec open question: footnotes.)*
- [x] **0.3** Show hard-coded HTML in a locked-down `WKWebView` (scripts
      off, remote loads blocked) inside the sandbox. Load one image through
      a minimal `mdview-file://` handler. *(Risk 2, ADR 0003, 0005.)*
- [x] **0.4** Open a real `.md` file from Finder and time double-click →
      first paint with signposts, cold and warm. *(Risk 1, spec 8.1, 8.2.)*
- [x] **0.5** Build a release version and check the app size. *(Risk 4,
      spec 8.4.)*
- [x] **0.6** Write up the results in progress.md. If cold open misses
      0.5 s, stop and revisit ADR 0003 before going on.

**Done when:** all four risks have a measured answer, and ADRs still stand
or have been revised.

## M1. Open a file and show it

The real project structure, with the simplest working path from file to
screen.

- [x] **1.1** Create the project layout from architecture.md: app target,
      local `MDViewCore` package with a test target, `fixtures/` folder.
- [x] **1.2** Register the Markdown file types in Info.plist so mdview
      appears in Open With and can be the default app. *(1.1, 1.2)*
- [x] **1.3** `MarkdownDocument` (read-only `NSDocument`): read the file,
      decode UTF-8, replace bad bytes with a notice. *(10.1, 10.2, 10.5)*
- [x] **1.4** Menus in code: File (Open, Open Recent, Close), Edit (Copy),
      Window. Open panel at launch when nothing is open. *(1.3, 1.7, 1.8)*
- [x] **1.5** `PreviewController` with a locked-down web view; show
      a minimal HTML version of the file (paragraphs and headings only).
- [x] **1.6** Multiple files, Dock drop, already-open files brought to the
      front, unreadable-file alert. *(1.4, 1.5, 1.6, 10.3)*
- [x] **1.7** Add the early web view start and signposts from the
      architecture performance plan; record cold/warm times.

**Done when:** double-clicking a `.md` file opens a window showing its
headings and paragraphs, and section 1 of the spec passes.

## M2. Render all of Markdown (done 2026-11-05)

All in `MDViewCore`, test-first against fixture files.

- [x] **2.1** Write `fixtures/elements.md` and `fixtures/front-matter.md`,
      plus expected-HTML test setup. *(2.16)*
- [x] **2.2** `HTMLRenderer` for paragraphs, line breaks, emphasis,
      strikethrough, inline code, horizontal rules, with HTML escaping.
      *(2.2, 2.3, 2.7, 2.10, 2.12)*
- [x] **2.3** Headings with GitHub-style anchors (`HeadingSlugger`).
      *(2.1, groundwork for 4.3)*
- [x] **2.4** Lists, nested lists, start numbers, task lists. *(2.4, 2.5)*
- [x] **2.5** Blockquotes (nested, with lists and code inside). *(2.6)*
- [x] **2.6** Code blocks (plain for now) and tables with alignment,
      each scrolling sideways on its own. *(2.8, 2.9)*
- [x] **2.7** Strip front matter; turn off smart punctuation; link bare
      web addresses. *(2.13, 2.14, 2.15)*
- [x] **2.8** `preview.css`: system fonts, ~80-character centred column,
      light and dark colours. *(6.3, 6.4)*
- [x] **2.9** Fuzz test: random and truncated input never crashes or
      hangs. *(10.4)*
- [x] **2.10** Look over `elements.md` and `front-matter.md` in the app
      (light and dark), then record their expected HTML
      (`MDVIEW_RECORD_EXPECTED=1`) so later changes are caught.
      Re-measure memory with `typical.md` (spec 8.5). *(2.16)*

**Done when:** `elements.md` renders completely and correctly, and spec
section 2 passes.

## M3. Images, links and folder access (tasks done 2026-11-05; manual checks listed in progress.md)

- [x] **3.1** `FolderAccess`: save and restore folder grants as
      security-scoped bookmarks. *(9.6)*
- [x] **3.2** Folder access bar and picker; reload images once granted.
      *(9.5, 9.7)*
- [x] **3.3** `AssetSchemeHandler` serving local images; rewrite relative,
      absolute and `file://` image paths; renderer checks file exists.
      *(3.1–3.4, 3.6)*
- [x] **3.4** Remote images become alt-text placeholders (done in 3.3); confirm
      the content rule list blocks anything remote, with an automated
      test; refuse to show the page if the list fails to load.
      *(3.5, 9.1, 9.8, ADR 0006)*
- [x] **3.5** `LinkRouter`: web and mail links, anchors, other Markdown
      files (with `#anchor`), other local files, missing files, link
      tooltips. *(4.1–4.6)*
- [x] **3.6** Write `fixtures/images.md` and `fixtures/links.md`; test
      against them. *(3.7)*

**Done when:** spec sections 3 and 4 and criteria 9.5–9.7 pass.

## M4. Automatic reload

- [x] **4.1** `FileWatcher` with `DispatchSource`, debouncing, and
      re-watching after save-by-replace. *(5.1, 5.3)*
- [x] **4.2** Swap in new content while keeping the scroll position;
      refresh changed images. *(5.2, 5.5)*
- [x] **4.3** Handle the file disappearing and coming back. *(5.4)*
- [ ] **4.4** Test with a few real editors (for example TextEdit, Xcode,
      VS Code, vim).

**Done when:** spec section 5 passes with each tested editor.

## M5. Window features

- [ ] **5.1** Find bar on `WKWebView.find`. *(6.6)*
- [ ] **5.2** Zoom in, zoom out, actual size. *(6.7)*
- [ ] **5.3** Print and Save as PDF. *(6.8)*
- [ ] **5.4** Reveal in Finder. *(6.9)*
- [ ] **5.5** Open in Editor, Change Editor, missing editor handling.
      *(6.10–6.12)*
- [ ] **5.6** Check tabs, title bar path menu, state restoration and text
      selection all work. *(6.1, 6.2, 6.5, 6.13)*
- [ ] **5.7** Keyboard and VoiceOver pass. *(6.14)*

**Done when:** spec section 6 passes.

## M6. Code highlighting

- [ ] **6.1** Scanner and the rule-table format; tests for the four token
      kinds and malformed input. *(7.2, 7.6, ADR 0004)*
- [ ] **6.2** Rule tables for Swift, Python, JavaScript/TypeScript.
- [ ] **6.3** Rule tables for shell, JSON, YAML, HTML, CSS.
- [ ] **6.4** Language tag aliases; unknown/untagged blocks stay plain.
      *(7.1, 7.4)*
- [ ] **6.5** Light and dark token colours with 4.5:1 contrast. *(7.5)*
- [ ] **6.6** Write `fixtures/code.md`; check a 2,000-line block against
      the speed targets. *(7.3, 7.7)*

**Done when:** spec section 7 passes.

*M6 only depends on M2, so it can be done before M3–M5 if you'd rather
see colours sooner.*

## M7. Speed, polish and v1 release

- [ ] **7.1** Write `fixtures/typical.md`, `fixtures/large.md` and the
      `edge/` files; a timing script for double-click → first paint.
- [ ] **7.2** Measure everything in spec section 8; fix anything that
      misses. *(8.1–8.6)* Memory is over target (see progress.md,
      2026-11-05): about 70 MB is fixed overhead before any content.
      Options include dropping the refilled spare (−9 MB), trimming what
      WebKit keeps per page, or revisiting the 100 MB target. Measure each process's
      `phys_footprint` after at least 10 s (WebKit's GPU process has a
      start-up peak of ~135 MB) and add them up, several runs.
- [ ] **7.3** Privacy check: network monitor during a test session, check
      entitlements, confirm the only package. *(9.1–9.4)*
- [ ] **7.4** App icon and About box.
- [ ] **7.5** Decide distribution (build from source, or notarised
      GitHub release) and write it up as an ADR.
- [ ] **7.6** Go through every spec criterion with the written checklist;
      fix what fails.
- [ ] **7.7** Set mdview as the default `.md` app and use it daily for a
      week. *(Vision success measure.)*
- [ ] **7.8** Tag v1.0 and publish as decided in 7.5. Add a license and
      update the README with install steps.

**Done when:** every spec criterion passes and mdview has replaced
whatever you used before.

---

## After v1 (not planned)

Ideas from the vision's non-goals, to revisit only if they stay fast and
native: footnotes (if not free in 0.2), more highlighted languages, an
outline of headings, math, Mermaid diagrams. Following a file that's
renamed or moved while open (today it shows "no longer available"; the
watcher could find the new path with `F_GETPATH` on its descriptor).
