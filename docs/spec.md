# Spec

What mdview v1 does, plus the edit mode planned for v1.1 (section 11),
and how we know each part works. See
[vision.md](vision.md) for why. How it's built belongs in
[architecture.md](architecture.md).

Each feature has numbered acceptance criteria (AC). A feature is done when
every AC passes. "Typical file" means a Markdown file under 100 KB.

**Platform:** macOS 15 Sequoia or later, on Apple silicon and Intel Macs.
Every criterion must pass on macOS 15 as well as on the latest release.

---

## 1. Opening files

mdview opens Markdown files from Finder, from its own Open dialog, and from
the Dock.

**Supported files:** `.md`, `.markdown`, `.mdown`, `.mkd`. The first two
are macOS's own `net.daringfireball.markdown` type; macOS doesn't know the
other two, so mdview declares `com.inferly.mdview.markdown-extension` for
them. Text is read as UTF-8.

| AC | Criterion |
|---|---|
| 1.1 | After installing, mdview appears in Finder's **Open With** menu for every supported extension. |
| 1.2 | mdview can be set as the default app for `.md` via Finder's **Get Info → Open with → Change All**, and then double-clicking any `.md` file opens it in mdview. |
| 1.3 | **File → Open…** (Cmd+O) shows the standard macOS open panel, filtered to supported files. Choosing a file opens it. |
| 1.4 | Selecting several files in Finder and opening them opens one window per file. |
| 1.5 | Dropping a supported file onto the Dock icon opens it. |
| 1.6 | Opening a file that's already open brings its existing window to the front instead of opening a second copy. |
| 1.7 | **File → Open Recent** lists recently opened files (standard macOS behaviour, including **Clear Menu**). |
| 1.8 | Launching mdview with no file shows the Open panel. It does not show an empty window. |

## 2. Rendering Markdown

mdview renders CommonMark plus the GitHub-flavored extensions listed below,
parsed with Apple's `swift-markdown`.

| AC | Criterion |
|---|---|
| 2.1 | **Headings** H1–H6 render with clearly decreasing sizes; H1 and H2 have a divider line under them. |
| 2.2 | **Paragraphs** wrap to the window width. A single line break inside a paragraph does not start a new line; a blank line starts a new paragraph. |
| 2.3 | **Emphasis:** *italic*, **bold**, ***bold italic*** and ~~strikethrough~~ render as such. |
| 2.4 | **Lists:** bulleted and numbered lists render with correct markers and indentation, nested at least 4 levels deep. Numbered lists respect their starting number. |
| 2.5 | **Task lists:** `- [ ]` and `- [x]` render as unchecked and checked boxes. The boxes are read-only. |
| 2.6 | **Blockquotes** render indented with a vertical bar, including nested quotes and quotes containing lists or code. |
| 2.7 | **Inline code** renders in the system monospaced font on a subtle background. |
| 2.8 | **Fenced and indented code blocks** render in the system monospaced font on a background panel. Long lines scroll horizontally within the block; they don't wrap or widen the window. |
| 2.9 | **Tables** render with a header row, cell borders and the column alignment set in the Markdown (`:--`, `:-:`, `--:`). A table wider than the window scrolls horizontally on its own. |
| 2.10 | **Horizontal rules** (`---`, `***`) render as a thin divider. |
| 2.11 | **Links** render in the macOS link colour (light and dark). See section 4 for what clicking does. |
| 2.12 | **Inline HTML** is not rendered. It appears as plain text, so a file can never run scripts or load content. |
| 2.13 | **YAML front matter** (a block between `---` lines at the very start of the file) is hidden. Rendering starts with the content after it. A `---` anywhere else is still a horizontal rule. |
| 2.14 | **Bare web addresses** in normal text (`https://…`, `http://…`, `www.…`) become links, as on GitHub. Trailing punctuation such as a full stop, comma or closing bracket is not part of the link. Addresses inside inline code or code blocks stay plain text. |
| 2.15 | **Punctuation shows as written.** Straight quotes stay straight, and `--` and `...` are not turned into dashes or ellipses. |
| 2.16 | A [reference test file](#test-files) containing every element above renders with nothing missing, garbled or out of order. |

## 3. Images

| AC | Criterion |
|---|---|
| 3.1 | An image with a relative path (`![](img/a.png)`) loads relative to the Markdown file's folder (once folder access is granted, see 9.5). |
| 3.2 | An image with an absolute local path or a `file://` URL loads (once its folder is granted, see 9.5). |
| 3.3 | PNG, JPEG, GIF, HEIC, WebP and SVG are supported where macOS can display them. |
| 3.4 | Images wider than the window scale down to fit; smaller images show at their natural size. |
| 3.5 | A **remote image** (`http://`, `https://`) is never downloaded. Its alt text shows in a small placeholder instead. |
| 3.6 | A **missing or unreadable image** shows its alt text in the same placeholder. The rest of the document still renders. |
| 3.7 | Images load without delaying the first appearance of the text (see section 8). |

## 4. Links

| AC | Criterion |
|---|---|
| 4.1 | Clicking an `http://`, `https://` or `mailto:` link opens it in the system default app (browser, mail). mdview itself makes no network request. |
| 4.2 | Clicking a relative link to another Markdown file (`[x](other.md)`) opens that file in mdview. If its folder isn't granted yet, the folder picker from 9.5 appears first. |
| 4.3 | Clicking a heading anchor (`[x](#installation)`) scrolls to that heading, using GitHub-style anchor names. A link to `other.md#section` opens the file and scrolls there. |
| 4.4 | Clicking a link to any other local file opens it in its default app. |
| 4.5 | Hovering over a link shows its destination (tooltip or status). A Markdown link title (`[x](url "title")`) isn't shown; the destination is. |
| 4.6 | A link to a file that doesn't exist does nothing harmful. It shows a brief "File not found" message. |

## 5. Automatic reload

| AC | Criterion |
|---|---|
| 5.1 | When the open file is saved by another app, the preview updates within 0.5 s, with no user action. |
| 5.2 | After reload the scroll position stays where it was (or as close as the new content allows). |
| 5.3 | Editors that save by replacing the file (writing a new file and renaming it, as many do) still trigger a reload, and keep triggering it on later saves. |
| 5.4 | If the file is deleted or moved away, the window keeps showing the last content with a clear "File no longer available" notice. If the file comes back, it reloads. |
| 5.5 | A changed local image in the document also refreshes on the next reload. |

## 6. Windows and appearance

| AC | Criterion |
|---|---|
| 6.1 | Each file opens in its own standard macOS window, titled with the file name. The window's title bar offers the standard file-path menu (Cmd+click on the title). |
| 6.2 | Windows can be merged into tabs with the standard **Window → Merge All Windows** and the "Prefer tabs" system setting. |
| 6.3 | Text uses the system font at a comfortable reading size (16 px, as on GitHub), with a maximum line width (about 80 characters) centred in wide windows. A new window is wide enough for the full column. |
| 6.4 | The app follows the system **light/dark** setting and switches live when it changes, including code colours. |
| 6.5 | Text can be selected and copied (Cmd+C) as plain text. |
| 6.6 | **Edit → Find** (Cmd+F, Cmd+G) searches within the document using the standard find bar. In edit mode it searches the source (spec 11.9). |
| 6.7 | **View → Zoom In / Zoom Out / Actual Size** (Cmd+=, Cmd+−, Cmd+0) change the text size for that window, in the preview and in edit mode. |
| 6.8 | **File → Print…** (Cmd+P) prints the rendered document using the standard print panel (which also offers "Save as PDF"). |
| 6.9 | **File → Reveal in Finder** (Cmd+Shift+R) shows the file in Finder. |
| 6.10 | **File → Open in Editor** (Cmd+Shift+E) opens the current file in a chosen editor app. The first time, a standard app picker (starting in Applications) asks which editor to use. After that, the choice is remembered and the file opens there directly. |
| 6.11 | **File → Change Editor…** shows the same picker to choose a different editor. The menu item for 6.10 shows the editor's name (for example "Open in TextEdit"); before one is chosen it reads "Open in Editor…". MDView itself can't be chosen. |
| 6.12 | If the remembered editor has been deleted or moved, Open in Editor shows the picker again instead of failing. |
| 6.13 | On relaunch, macOS restores previously open windows (standard state restoration). This follows the system setting "Close windows when quitting an application": with it on (the default), windows come back after a force quit or Quit and Keep Windows (⌥⌘Q). When windows are restored, the Open panel isn't shown. |
| 6.14 | Everything is reachable by keyboard and readable with VoiceOver: headings are announced as headings, and links and images (by alt text) are announced as such. |

## 7. Code highlighting

Fenced code blocks with a language tag are coloured with a small
highlighter written inside the project.

| AC | Criterion |
|---|---|
| 7.1 | These language tags are highlighted (case doesn't matter): `swift`; `python` / `py`; `javascript` / `js` / `jsx`; `typescript` / `ts` / `tsx`; `sh` / `bash` / `zsh` / `shell`; `json`; `yaml` / `yml`; `html`; `css`. Close relatives use the same rules: `mjs`, `cjs`, `jsonc`, `htm`, `xml`, `svg`. |
| 7.2 | Each highlighted language distinguishes at least **keywords, strings, comments and numbers**, each in its own colour. |
| 7.3 | Strings and comments that span several lines (block comments, triple-quoted strings, template literals) are coloured correctly across lines. |
| 7.4 | Code blocks with no tag or an unknown tag render as plain monospaced text with no colouring. |
| 7.5 | Colours have readable contrast in both light and dark mode (at least 4.5:1 against the code background). |
| 7.6 | Malformed code (such as an unclosed string) never crashes or hangs the app; at worst, colouring is wrong to the end of the block. |
| 7.7 | A file with a 2,000-line code block still meets the speed targets in section 8 (highlighting may finish just after the text first appears). |

## 8. Performance

Measured on the development Mac (Apple silicon), from a release build,
using the [test files](#test-files).

| AC | Criterion |
|---|---|
| 8.1 | **Cold open:** app not running, double-click a typical file in Finder → rendered text visible in **under 0.5 s**. |
| 8.2 | **Warm open:** app already running, open a typical file → rendered text visible in **under 0.2 s**. |
| 8.3 | **Large file:** a 5 MB Markdown file opens with text visible in under 2 s, and scrolling stays smooth (no spinning cursor). |
| 8.4 | **Bundle size:** the built `.app` is **under 5 MB**. |
| 8.5 | **Memory:** a single open typical file uses under 110 MB, adding up mdview and its WebKit processes. (Raised from 100 MB in roadmap 7.2: about 70 MB is fixed WebKit and AppKit overhead, and the spare web view that keeps warm opens under 0.2 s costs 9 MB of the rest.) |
| 8.6 | **Idle:** with files open and nothing changing, the app uses ~0% CPU. |

## 9. Offline, privacy and safety

| AC | Criterion |
|---|---|
| 9.1 | The app makes **zero network requests**: a network monitor shows no traffic from mdview or its WebKit processes during a test session that opens every fixture file, including ones with remote images. (The app has the outgoing-network entitlement only because WebKit needs it to run in the sandbox, ADR 0006; it has no incoming-network entitlement.) |
| 9.2 | The app runs in the macOS App Sandbox, with read access only to files the user opens and folders the user has granted (see 9.5). It writes only to an open file, and only when the user saves it in edit mode (section 11, ADR 0008). |
| 9.3 | No telemetry, analytics, crash uploading or update checks. |
| 9.4 | The only package dependency is Apple's `swift-markdown` (and its `swift-cmark`). |
| 9.5 | **Folder access.** When a document refers to local images or files that the app can't read yet, the window shows a slim bar: "Allow MDView to show images and linked files in this folder." Clicking it opens the standard folder picker, pointed at the document's folder; the user can choose it or any folder above it. After granting, images and links load at once, without reopening the file. |
| 9.6 | A folder grant is remembered across launches and covers every file inside that folder, so the bar never appears again for those files. A document with no local images or links never shows the bar. |
| 9.7 | Dismissing the bar is allowed: the document still renders, with alt-text placeholders for the images it couldn't read. |
| 9.8 | If the web view's block list for remote content can't be loaded, the document is not shown; an error appears instead. |

## 10. Errors and edge cases

| AC | Criterion |
|---|---|
| 10.1 | An **empty file** opens to an empty, quiet window (no error). |
| 10.2 | A file that **isn't valid UTF-8** still opens: invalid bytes are replaced, and a small notice says the file may not display correctly. |
| 10.3 | A file that **can't be read** (no permission, vanished) shows a standard macOS alert naming the file and the reason. No empty window is left behind. |
| 10.4 | **Any Markdown input**, however malformed, renders something and never crashes or hangs the app. |
| 10.5 | Opening a **non-Markdown file** that's been forced into mdview (Open With → Other) shows its contents as plain text. |

## 11. Edit mode (v1.1)

A plain-text editor for the open file, swapped in place of the preview
([ADR 0008](adr/0008-edit-mode.md)). MDView stays a viewer first: nothing
is written unless the user saves.

| AC | Criterion |
|---|---|
| 11.1 | **View → Edit Mode** (Cmd+/) swaps the preview for an editor showing the file's full source, front matter included, in the same window. The menu item is checked while in edit mode; choosing it again swaps back to the preview. |
| 11.2 | Every window opens in preview, including windows restored on relaunch (6.13). Opening a file is no slower than in v1 (8.1, 8.2): the editor is only created when a window first switches to it. |
| 11.3 | The editor uses the system monospaced font, follows light/dark mode, and wraps long lines to the window width. There is no colouring and no automatic changes to what's typed: no smart quotes or dashes, no automatic links, no spelling corrections. |
| 11.4 | Undo and Redo (Cmd+Z, Shift+Cmd+Z), Cut, Copy, Paste and Select All work in the editor, from the Edit menu and the keyboard. Undo history survives switching to the preview and back. |
| 11.5 | Switching back to the preview renders the editor's current text, saved or not, in under 0.2 s for a typical file. |
| 11.6 | Unsaved edits show the standard edited marker in the window's title bar and close button. **File → Save** (Cmd+S) writes the file; it's dimmed when there's nothing to save. Nothing else writes it: no autosave, no Versions, no Save As. |
| 11.7 | Closing a window or quitting with unsaved edits asks the standard Save / Don't Save / Cancel question. |
| 11.8 | A saved file is UTF-8, keeps its byte order mark if it had one, and keeps its line endings. Text that's read and saved again unchanged gives the same bytes the file had. |
| 11.9 | In edit mode, **Edit → Find** (Cmd+F, Cmd+G) searches the source with the standard find bar. |
| 11.10 | Edit Mode is dimmed for a file that didn't decode cleanly as UTF-8 (the notice in 10.2, including UTF-16 files), so its original bytes can't be overwritten. |
| 11.11 | When the file changes on disk and there are no unsaved edits, it reloads as in section 5, in either mode. With unsaved edits, an alert says the file was changed by another app and offers **Keep My Edits** or **Reload from Disk**. MDView's own saves never cause a reload or this alert, and the file keeps being watched after them (5.3). |
| 11.12 | If the file can't be saved, an alert names the file and the reason, and the edits stay in the window. A locked or read-only file gets the standard "The file is locked" alert, whose **Save Anyway** saves it and leaves it locked. A file that has been deleted or moved away is never written back or saved somewhere else: Save says it's no longer available, and no save panel ever appears. |
| 11.13 | The editor is reachable by keyboard and readable with VoiceOver, as a standard text view. |
| 11.14 | A 5 MB file (8.3) can be switched to edit mode, scrolled and typed in without a spinning cursor. The app is still under 5 MB (8.4). |

---

## Out of scope for v1

Taken from the vision's non-goals: export beyond Print/PDF, remote
images, plugins, themes, a settings screen, Mermaid diagrams, math, and any
network access.

**Rich editing** stays out in v1.1 (ADR 0008): no side-by-side source and
preview, no colouring in the editor, no autosave or Versions, no Save As,
no new files, and no ticking task-list boxes in the preview (2.5).

**Footnotes** are also out: `swift-markdown` 0.9.0 doesn't support them
(checked in roadmap 0.2), so `[^1]` and its definition show as plain text.

## Test files

A folder of Markdown files kept in the repo for checking the criteria above
(location decided in the architecture doc):

- `elements.md`: every element in section 2, plus nested combinations
  (also a local and a remote image, and links, so it shows every kind of
  content in one place)
- `front-matter.md`: front matter at the top, plus a `---` rule further down
- `images.md`: relative (incl. `./`, `../`, spaces), missing, not an
  image, remote, unsafe and oversized images, and images inside links,
  tables, lists and quotes (absolute paths and `file://` are unit tested,
  since they depend on where the repository is)
- `links.md`: anchors, other Markdown files (incl. subfolders, `../`,
  spaces, with anchors), other files and folders, web and mail, reference
  links, missing files, and unsafe links
- `code.md`: one block per supported language, plus untagged, unknown and
  malformed blocks
- `typical.md`: about 50 KB of realistic README-style content (performance)
- `large.md`: about 5 MB (performance). It isn't stored in the repo: the
  timing script makes it by repeating `typical.md`, so the repo doesn't
  carry 5 MB of copies.
- `edge/`: empty, non-UTF-8 (Latin-1, UTF-16), plain-text, byte order
  mark, Windows line endings and control-character files, plus
  pathological ones: things left unclosed, very long lines, and nesting
  too deep to parse (spec 10.4)
- `expected/`: the expected HTML for each file above, used by the tests

## Open questions

