# Progress

Newest session first.

## 2026-11-05: Roadmap 8.6, outside changes while editing; size limit raised

**Done**
- Committed 8.5 (`9a6477b`).
- `MarkdownDocument` remembers the file's bytes as last read or saved
  (`bytesOnDisk`, set in `read` and after a save works). On a change from
  the watcher it reads the file once:
  - same bytes (our own save, or the file back unchanged): no reload,
    only `fileModificationDate` updated, so undo history stays and Save
    doesn't warn
  - different, no unsaved edits: reload as before (editor too)
  - different, unsaved edits: a sheet, "“c.md” was changed by another
    app." with **Keep My Edits** (default) or **Reload from Disk**. Only
    one at a time. Keep remembers the file's bytes and date at the moment
    of answering.
- "No longer available" notice now goes when the file is back, even if
  unchanged (it used to go with the reload).
- **Bug found and fixed:** after a save, further typing didn't mark the
  document edited, so a reload could silently replace it. NSTextView
  had coalesced the new typing into the undo group already counted as
  saved. Saving now calls `breakUndoCoalescing()` first, as TextEdit does.
- Checked on a release build with System Events and shell writes:
  - clean + outside change: editor shows the new text
  - our own save: no read in the log, Undo Typing still enabled
  - watcher still works after our save (5.3)
  - typing after a save: edited again
  - unsaved + outside change: the sheet; a second change while it shows
    adds no second sheet; Keep leaves the edits; the same version written
    again doesn't ask; Save then writes our text with no other alert
  - Reload from Disk: editor and preview show the disk text, not edited
  - the same question in the preview with unsaved edits
  - deleted, then put back with the same bytes: the notice goes, no read
  - Undo still works after saving
- 271 core tests pass; release build, no warnings.

**Size**
- After 8.6 the bundle was **5,029,274 bytes**, over spec 8.4's 5 MB
  (8.5: 4,969,450). The release build isn't stripped: plain `xcodebuild
  build` keeps local symbols (only archive and install strip). Stripping
  measured about 845 KB less per architecture (arm64 2,408,048 →
  1,562,256), so about 3.3 MB in all.
- The owner chose to raise the limit rather than strip or cut code. Spec
  8.4 is now **under 6 MB**, with the reason in the spec; vision.md's
  table notes it.

**Open**
- Still the rough edge from 8.3: closing a window whose file is gone and
  choosing Save offers NSDocument's "Save As…", which does nothing.
- Testing note: with System Events, pause about 0.3 s after the End key
  before typing, or keystrokes can go missing.

**Next**
- 8.7: measure (open times, preview after editing, 5 MB file in edit
  mode, size, offline), checklist section 11, version 1.1.0, tag and push.

## 2026-11-05: Roadmap 8.5, find and zoom in edit mode

**Done**
- Committed 8.4 (`5aee938`).
- Find in edit mode uses the text view's own standard find bar
  (`usesFindBar`). Find…, Find Next, Find Previous and Use Selection for
  Find go to `SourceEditor.performFind`, which calls
  `performTextFinderAction` with the action as the sender's tag. In the
  preview, our `FindBar` works as before.
- Incremental searching is off. With it on, Find Next and Previous stayed
  on the first match (checked through the menu and with ⌘G).
- Zoom: one level per window. Zoom In / Out / Actual Size set the preview
  and the editor together; the editor's font is the system size × zoom,
  rounded. A new editor starts at the window's zoom.
- Checked on a release build with System Events:
  - ⌘F in edit mode opens the standard bar (AXSearchField focused).
    Return selects the first "apple"; Find Next steps through all three
    and wraps; Find Previous goes back; Find Next works with the bar
    closed; Esc returns focus to the editor.
  - Use Selection for Find puts the selected word in the search field.
  - Zoom on a 120-line file: the text's height goes 1847 → 1968 → 2089
    → 2210 pt for 90 / 100 / 110 / 125 %, and back to 1968 on Actual
    Size, also when that's chosen in the preview.
  - Keyboard and VoiceOver: switching to edit mode focuses the editor,
    an AXTextArea announced as "Markdown source"; switching back focuses
    the preview's AXWebArea. Every command has a menu item and shortcut.
    A full VoiceOver pass is left for the 8.7 checklist (hand check, as
    for spec 6.14).
- Release build, no warnings.

**Measurements**
- Bundle: **4,969,450 bytes**, about 30 KB under spec 8.4's 5 MB
  (5,000,000 bytes). v1.0 was 4,936,346, so edit mode has cost 33 KB so
  far (both architectures). `du -sk` says 4,868. 8.6 must stay small.

**Next**
- 8.6: outside changes while editing (ignore our own saves, then Keep My
  Edits / Reload from Disk).

## 2026-11-05: Roadmap 8.4, the editor and the Edit Mode toggle

**Done**
- Committed 8.3 (`244aeb4`).
- `App/SourceEditor.swift`: a plain `NSTextView` in a scroll view.
  System monospaced font at the system size, `textColor` on
  `textBackgroundColor` (follows light and dark), lines wrap to the
  window, 16 pt inset. Not rich text. Every automatic change is off:
  quotes, dashes, text replacement, spelling correction, link and data
  detection, completion, spell and grammar checking. Accessibility label
  "Markdown source".
- `DocumentWindowController`: View ▸ Edit Mode ⌘/ (checked while
  editing). The editor is made on the first switch and then kept, so the
  window keeps its undo history. Edits go straight to the document. The
  preview re-renders on the way back only if the text changed. Edit Mode
  is dimmed when `canEdit` is false. A reload from disk updates the
  editor too (cursor kept as close as possible; nothing happens if the
  text is the same).
- Edit menu: Undo ⌘Z, Redo ⇧⌘Z, Cut, Paste added around Copy and Select
  All. Print is dimmed in edit mode (spec 11.1 now says so).
- Until 8.5, Find and Zoom are dimmed in edit mode, so they can't act on
  the hidden preview.
- Checked on a release build with System Events (small test file with
  front matter):
  - The editor shows the full source, front matter included; the menu
    item gets its check mark; ⌘/ toggles both ways.
  - Typed `He said "hi" -- ok... (c) teh`: saved exactly so, with no
    curly quotes, dashes, ellipsis, © or correction.
  - Edited marker on after typing. Undo ("Undo Typing") back to the saved
    text clears it; Redo sets it again.
  - The preview after switching back shows the unsaved words (found in
    the web view's accessibility tree).
  - Undo still works after going to the preview and back.
  - ⌘S saves the typed text and clears the marker.
  - In the preview, Cut, Paste and Undo are dimmed; in edit mode, Print.
  - `latin1.md`: Edit Mode dimmed, and ⌘/ does nothing.
- Release build, no warnings. Core unchanged (271 tests passed in 8.3).

**Open**
- After a save, Undo is empty: our own save comes back from the watcher
  as a reload (`revert`), which clears the undo history. Ignoring our own
  saves is already 8.6's job; added the undo note to it.
- Not measured yet: preview after editing under 0.2 s (11.5) and the
  5 MB file in edit mode (11.14). Both are in 8.7.
- In System Events, the Undo item is renamed ("Undo Typing"), so scripts
  should click it by position.

**Next**
- 8.5: Find and Zoom in edit mode; keyboard and VoiceOver.

## 2026-11-05: Roadmap 8.3, saving the document

**Done**
- Committed 8.2 (`391b137`).
- `MarkdownDocument` can now be saved, though nothing edits it until the
  editor comes in 8.4:
  - `updateText(_:)` for the editor; the edited state will come from the
    window's undo manager, which is the document's.
  - `canEdit` (false for files with bad bytes, spec 11.10).
  - `writableTypes(for:)` returns the file's own type for a plain save.
    Info.plist keeps the Viewer role; this was simpler than changing how
    Launch Services sees the app.
  - `data(ofType:)` through `UTF8Text.encode`, refusing if `!canEdit`.
  - File ▸ Save ⌘S, dimmed unless there are unsaved edits, so ⌘S in the
    preview never touches a file.
  - Save of a file that's gone shows our alert; `prepareSavePanel`
    returns false, so no route ever opens a save panel (no Save As).
  - While there are unsaved edits, a change on disk isn't reloaded (so it
    can't throw edits away). 8.6 adds the Keep / Reload question.
- Checked on a release build with a temporary hook (env variable) that
  marked the document edited, driving the app with System Events. The
  hook is removed; it isn't in the commit.
  - Edited marker: the close button's `AXEdited` is true; File ▸ Save is
    enabled, then dimmed again after saving.
  - `bom.md`: saved with the byte order mark and original bytes intact,
    plus the new line. `crlf.md`: CRLF bytes intact.
  - Close with edits: the standard Save / Don't Save / Cancel sheet.
    Cancel keeps the window and the file unchanged; Don't Save closes
    without writing; Save on Quit wrote the file, then quit.
  - Locked (`chflags uchg`) and read-only (`chmod 444`) files: NSDocument's
    "The file is locked" alert with Save Anyway / Cancel. Save Anyway works
    in the sandbox and leaves the lock and permissions as they were. I
    kept it (standard behaviour, an explicit choice); spec 11.12 now says
    so.
  - Deleted file: menu Save shows "“gone.md” can't be saved because it's
    no longer available." Before the fix NSDocument offered Save As.
  - `latin1.md` with edits: Save stays dimmed.
- spec 11.6 (Save dimmed when nothing to save), 11.8 and 11.12 reworded
  to match. architecture.md describes the saving rules.
- Release build, no warnings; 271 core tests pass; app 4,828 KB
  (`du -sk`, +20 KB).

**Open**
- Rough edge: closing a window whose file is gone, then choosing Save in
  the close question, gets NSDocument's "location cannot be determined"
  alert with a Save As… button. Pressing it does nothing (the panel is
  refused) and the window stays open with its edits. Safe, but the button
  is misleading. Could be handled with the disappeared state in 8.6.
- When driving the app with System Events, set it frontmost first:
  after one window closes, the next isn't key, and Close does nothing.
- Edit Mode being dimmed for bad-byte files is checked in 8.4, once the
  menu item exists.

**Next**
- 8.4: the editor and the View → Edit Mode toggle.

## 2026-11-05: Roadmap 8.2, saving text back as bytes

**Done**
- Committed 8.1 and the v1.1 plan (`49a0f48`).
- `UTF8Text.encode(_:byteOrderMark:)` in MDViewCore: text → UTF-8 bytes,
  with the byte order mark first if the file had one. It returns
  `[UInt8]`, like `decode` takes any byte collection, so MDViewCore
  stays Foundation-free here; the app will wrap it in `Data`.
- `DecodedText` gains `hadByteOrderMark` (defaults to false, so existing
  callers are unchanged). `decode` now sets it.
- Tests (7 new, 271 in all, all pass):
  - plain UTF-8, empty, byte order mark put back
  - mixed line endings (`\r\n`, `\n`, `\r`) written exactly as in the text
  - an edit to one line of a CRLF file changes only that line
  - every fixture (18) that decodes cleanly saves back to exactly its own
    bytes; `latin1.md` and `utf16.md` are reported as invalid, which is
    what will dim Edit Mode for them (spec 11.10)
  - `bom.md` and `crlf.md` really do have a mark and CRLF, so the
    round-trip covers them
- App (debug) builds with no warnings; nothing in the app uses `encode`
  yet.

**Next**
- 8.3: editable `MarkdownDocument` (`data(ofType:)` through
  `UTF8Text.encode`, edited state, Save, close question, save errors,
  dimmed for files with bad bytes).

## 2026-11-05: Roadmap 8.1, edit mode accepted; sandbox save spike

**Done**
- The owner accepted ADR 0008. Updated to match: vision.md ("a viewer
  first", "No rich editing"), CLAUDE.md (the read-only rule is now
  "writes only on save"), the statuses of ADR 0002 and 0005, and
  architecture.md's ADR table.
- Entitlement is now `files.user-selected.read-write`. Trap found: the
  project's build setting `ENABLE_USER_SELECTED_FILES = readonly` adds
  its own read-only entitlement, so the first build had both. The
  setting is now `readwrite` too (both configurations); the signed
  release has only read-write.
- Spike, with temporary code (an env variable made `MarkdownDocument`
  append a line and save twice through `NSDocument`), on a release build.
  Removed afterwards; `MarkdownDocument.swift` is unchanged.
  - **Saving works in the sandbox** for a file opened from Finder
    (`open`): both saves succeeded in about 15 ms. NSDocument saves
    safely: the file got a new inode (written elsewhere, then swapped in).
  - **Saving works for a file opened through a folder grant.** The owner
    granted a test folder in the picker and opened a linked file; both
    spike saves landed in it.
  - **Old read-only grants** aren't an issue in practice: there were none
    stored ("restored 0 of 0"), and an ad-hoc rebuild drops grants anyway
    (note in `FolderAccess`), so after updating to v1.1 every grant is made
    again under the read-write entitlement. ADR 0008's fallback (the save
    error alert, spec 11.12) still covers it.
  - **The watcher survives our own saves.** After two safe saves, an
    outside append, an outside rename-save and another append each
    reloaded the file (spec 5.3).
  - **Our own save comes back as a reload** about 95 ms later (same
    bytes). Harmless today, but 8.6 must ignore it, as ADR 0008 point 7
    plans, or it would reset the editor.
- Checked after removing the spike: 264 core tests pass; release build
  succeeds with no warnings; `check-offline.zsh` passes; app 4,808 KB
  (`du -sk`).

**Open**
- Possible v1 bug (spec 4.2), seen during the spike: the owner clicked a
  link to a file in an ungranted folder, the picker appeared, they
  granted the folder, and the linked file didn't open. Clicking the link
  again opened it. `withAccess(to:then:)` in `DocumentWindowController`
  is meant to open it after the grant. Not looked into yet.
- `/usr/bin/log`, not `log`: in zsh, `log` is a builtin.

**Next**
- 8.2: `UTF8Text.encode` with round-trip tests.

## 2026-11-05: v1.1 planned, edit mode (ADR 0008 proposed)

**Done**
- Interviewed the owner about an edit mode toggle for v1.1. Their
  choices: swap the editor in place of the preview (no split view);
  save only on ⌘S, with the standard unsaved-changes question (no
  autosave); View → Edit Mode on ⌘/ (⌘E and ⇧⌘E are taken), no toolbar;
  ask Keep My Edits / Reload from Disk when the file changes on disk
  under unsaved edits; the preview shows the unsaved text; a plain
  monospaced editor with no colouring; editing dimmed for files with bad
  bytes or UTF-16; every window opens in preview.
- ADR 0008 written, status Proposed. It goes against the vision's "No
  editing" non-goal, CLAUDE.md's read-only rule, ADR 0002's read-only
  document and ADR 0005's read-only entitlement, so those change only
  once the owner accepts it (roadmap 8.1).
- spec.md: new section 11 (14 criteria, marked v1.1); 6.6, 6.7 and 9.2
  mention edit mode; "Out of scope" drops editing and lists what rich
  editing stays out.
- roadmap.md: new milestone M8 (tasks 8.1–8.7). architecture.md lists
  ADR 0008. No code changed.

**Open**
- ADR 0008 needs the owner's OK.
- To check in 8.1: saving inside the sandbox, files opened through
  folder grants made under the read-only entitlement, and the watcher
  after our own save.

**Next**
- 8.1, once ADR 0008 is accepted.

## 2026-11-05: Roadmap 7.8, v1.0

**Done**
- `LICENSE`: MIT, "Copyright (c) 2026 Saravanakumar Selladurai" (the
  owner chose MIT).
- Version 1.0.0 (`MARKETING_VERSION`), build 1. The About box shows it.
- `README.md` rewritten for v1:
  - what MDView does
  - install by building from source (ADR 0007): clone, `xcodebuild`
    release, copy to /Applications, set as default with Get Info →
    Change All
  - how to update
  - folder access
  - the layout, now with `scripts/` and `checklist.md`
  - the license, naming both packages and theirs
- Checked the README's exact commands from a fresh clone into a stand-in
  Applications folder: the build succeeds, the copy works, and the update
  (remove, then copy) works. My first wording said `cp -R` onto an
  existing app nests the new one inside it. It merges instead, which is
  the actual reason to remove the old copy first.

- Published: the owner made https://github.com/sarawanakumar/mdview. It's
  the `origin` remote now, and the README's clone command uses it. `main`
  and the annotated tag `v1.0` are pushed. The tag was first made one
  commit earlier, then moved (before any push) so v1.0 includes the real
  clone URL.
- 7.8 is ticked, so the v1 roadmap is complete.

**Next**
- Nothing planned. "After v1" ideas are listed at the end of roadmap.md.

## 2026-11-05: Roadmap 7.7, a week of daily use

**Done**
- The owner set MDView as the default app for `.md` and used it daily
  for a week. Their report: "working fine". No problems to fix.
- That's the vision's last success measure ("I've set it as my default
  app for `.md` and don't miss anything"), so 7.7 is ticked.

**Next**
- 7.8: choose a license, add README install steps (ADR 0007), tag
  v1.0 and push the repository.

## 2026-11-05: Roadmap 7.6, release checklist

**Done**
- `docs/checklist.md`: all 82 spec criteria, each with how it's checked
  (unit tests, a script, an earlier in-app check, or by hand) and when
  it last passed, plus 11 numbered hand checks with steps. It replaces
  the "checklist in `fixtures/`" the architecture doc planned. A `.md`
  there would have been picked up as a test file. CLAUDE.md and
  architecture.md point to it.
- Run today on the release build:
  - 264 core tests pass
  - `check-offline.zsh` passes (18 files, 23 processes, no sockets)
  - `time-open.swift`: cold 484 ms, warm 133 ms, large 1,115 ms
  - Open With offers MDView for `.md`, `.markdown`, `.mdown` and `.mkd`
- Found and fixed a side effect of my own: the temporary comparison
  builds from 7.2 (`build/ab/`) had been registered with Launch Services,
  and one had become the default app for `.mdown` and `.mkd`. They're
  now unregistered and deleted. Those two extensions now default to
  `build/mdview.app`, where before (roadmap 1.2) they defaulted to VS
  Code. I didn't change the owner's defaults back; that's theirs to do
  (Finder → Get Info → Open with → Change All).

**Open: hand checks** (checklist items 1–10; 11 passed in 7.2)
- Never checked so far: Dock drop (1.5), link hover (4.5), ⌘-click title
  path menu (6.1).
- Tested in parts, the rest needs a person: a real folder grant (9.5),
  web and mail links (4.1), GUI editors' own windows (5.1), the Window
  menu's tab items (6.2), live dark mode (6.4), the print panel (6.8),
  the editor picker (6.10), VoiceOver (6.14).

**Hand checks: all passed** (the owner ran checklist items 1–10 on the
release build). With these, every spec criterion passes, so 7.6 is
ticked. The checklist's "Last checked" column is updated.

**Next**
- 7.7: set MDView as the default `.md` app and use it daily for a week.

## 2026-11-05: Roadmap 7.5, distribution (ADR 0007)

**Done**
- Checked what each option means on macOS 26.6:
  - **A fresh clone** builds a universal release in 31 s. It's ad-hoc
    signed with the hardened runtime and has no quarantine flag, so it
    opens and runs from wherever it's built.
  - **The same app downloaded** would be quarantined. `spctl` rejects
    it: Gatekeeper needs a Developer ID and notarisation.
- Wrote ADR 0007, status **Proposed**: v1 is build-from-source only,
  with README install steps in 7.8. A notarised GitHub release (needs a
  paid developer membership, plus the license texts in the bundle) stays
  open for later. An un-notarised zip is rejected.
- The owner accepted ADR 0007, so 7.5 is ticked. Roadmap 7.8 now says
  what "publish" means.

**Next**
- 7.6: go through every spec criterion with the written checklist.

## 2026-11-05: Roadmap 7.4, app icon and About box

**Done**
- **Icon:** `scripts/make-icon.swift` draws it with Core Graphics: a blue
  rounded square on the macOS icon grid (824 of 1024), a white page with
  a folded corner, and the Markdown "M↓" mark. It writes the ten sizes
  into `App/Resources/Assets.xcassets/AppIcon.appiconset`, and the build
  uses it (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`). There's no
  design tool or image file to keep in step; edit the script and run it.
- The first version had a gradient and soft shadows. Those compress
  badly, and the app grew to 5,207,101 bytes, over spec 8.4. The flat
  version adds about 87 KB.
- **About box:** the standard panel, from a new `showAbout` action. It
  shows:
  - the icon
  - "MDView" (the bundle name is "mdview", so the name is passed in)
  - version 0.1.0 (1)
  - "Copyright © 2026 Saravanakumar Selladurai" (from the git author;
    `NSHumanReadableCopyright`)
  - two lines of credits: what mdview is, and that it uses swift-markdown
    (Apache 2.0) and swift-cmark (BSD 2-Clause)

  It was checked in the release app with a temporary hook, since
  removed, that drew the panel to an image.

**Measurements**
- Bundle: 4,936,346 bytes (spec 8.4: under 5 MB, about 64 KB left).
  Assets.car is 76 KB and AppIcon.icns 11 KB.
- Timing unchanged: cold 480 ms, warm 118 ms, large 1,144 ms (3 runs).
- All 264 core tests pass, and both builds have no warnings.

**Open**
- Any binary release must ship the full license texts of swift-markdown
  (Apache 2.0, with its NOTICE) and swift-cmark (BSD 2-Clause and the
  other notices in its COPYING). For roadmap 7.5 and 7.8.
- The icon design is a first proposal; easy to change in the script.
- Size headroom is small (64 KB). Anything added to the bundle from now
  on should be measured.

**Next**
- 7.5: decide distribution (an ADR).

## 2026-11-05: Roadmap 7.3, privacy check

**Done** (release build from 7.2, unchanged)
- **9.1, network:** while mdview opened all 18 fixture files, `nettop`
  recorded every socket on the Mac for 60 s. The files included
  images.md's remote and unsafe images and links.md's web links. Then
  images.md was edited, so it reloaded with two more remote images, and
  the 5 MB file was opened. mdview's 23 processes (the app, GPU,
  Networking and 20 WebContent) never appeared in nettop's output, and
  `lsof` found no internet sockets for them. In the same window, nettop
  saw Chrome, Slack, Bitrise and others.
  - Controls: a local `curl` to 127.0.0.1 showed up in nettop (498 bytes
    in, 77 out), and the script's checks find Chrome's open connection.
  - The system DNS service's log shows lookups by sharingd, rapportd and
    Python (the control), and none by mdview or its WebKit processes.
- **9.2, sandbox:** the signed build has exactly four entitlements:
  app-sandbox, user-selected read-only, app-scope bookmarks and
  network.client. There is no network.server. The kernel's
  `sandbox_check` says the running app is sandboxed, and says no for a
  shell, as a control. File access itself was tested in M3.
- **9.3, no telemetry:** no networking, analytics, crash-report or
  update code in `App/` or `MDViewCore`, and none in the two packages'
  sources. The binary imports no networking symbols and links only system
  libraries. Info.plist has no update feed, and the bundle holds only the
  executable, Info.plist and preview.css.
- **9.4, packages:** both `Package.resolved` files pin exactly
  swift-markdown 0.9.0 and swift-cmark 0.9.0. The Xcode project has one
  package reference, the local MDViewCore.
- `scripts/check-offline.zsh` repeats the 9.1 session: it copies the
  fixtures to `build/`, opens them all, edits one, and fails if any
  mdview process had a socket. It passed. Noted in CLAUDE.md and
  architecture.md.

**Observed, not a task**
- Each window gets its own WebContent process (20 for 19 windows). That
  fits spec 8.5, which is about one file, but many open windows cost
  roughly 30–50 MB each.

**Next**
- 7.4: app icon and About box.

## 2026-11-05: Roadmap 7.2, measuring spec section 8

**Done**
- Cold-open timeline, using temporary signposts (since removed), median
  of 6 runs, in ms after `open`:
  - `main` starts at ~180. Everything links from the system's shared
    cache, so there's nothing to trim there.
  - `NSApplication.shared` takes ~55, and AppKit's own launch work
    another ~85.
  - Making a web view holds the main thread ~40.
  - WebKit takes ~80 from `loadHTMLString` to `didFinish`.
- Two changes on the open path:
  - **The block list lookup starts in `applicationWillFinishLaunching`,
    with WebKit's callback API.** The old `Task` didn't start until
    AppKit had finished launching, ~85 ms later. Now the list is usually
    ready before the file is read, and the spare exists by then too
    (spareReady 358 against 395).
  - **Rendering starts before the window is built,** in a detached task,
    instead of after.

  Neither changes the offline protection: no web view exists without
  the block list, and a failure still shows mdview's own error
  (spec 9.8).
- Tried and dropped: `malloc_zone_pressure_relief` after a page shows.
  The app process holds ~19 MB that's freed but still resident (a 9.9 MB
  empty large region, plus fragmentation), and the call released none
  of it.

**Measurements** (release build; the load average was 4–7, at one
point 13, from other apps)

| Spec | Result | Target |
|---|---|---|
| 8.1 cold | 455 ms median (8 runs) in a quieter spell; 480–530 ms at load 4–7 | under 500 ms: borderline |
| 8.2 warm | 148–198 ms median | under 200 ms: pass |
| 8.3 large (5.0 MB) | 1,127–1,170 ms median | under 2 s: pass (scrolling not yet checked) |
| 8.4 bundle | 4.72 MB (`du -sk` 4,720) | under 5 MB: pass |
| 8.5 memory, typical.md | 103–106 MB | under 110 MB (was 100): pass |
| 8.6 idle | 0 s of CPU time in 30 s, three files open, all 7 processes | ~0%: pass |

- Cold-open runs that alternated with the committed build couldn't
  separate the two: 529 against 542 ms, then 497 against 460 ms. The
  machine's noise (±50 ms) is bigger than the gain. The timeline shows
  the block list now arrives before the file, as intended.
- Memory, typical.md (each process's footprint after 12 s, 3 runs):
  app 29–41, page 30–49 (mostly graphics tiles), GPU 14–19, networking
  4, spare 9 MB. Without the refilled spare it's **95 MB**, but warm
  opens go from ~172 to ~200 ms (two rounds of 12, alternating). The
  spare decides between 8.2 and 8.5. **The owner chose to keep the spare
  and raise spec 8.5 to 110 MB,** so 8.5 now passes at 103–106 MB. ADR
  0003, which mentions the old limit, has a dated note.

**Final checks** (by the owner, after the 7.2 commit)
- `swift scripts/time-open.swift`, 5 runs, load average 5.7: cold
  median 463 ms (427–485, every run under 500), warm 131 ms (118–151),
  large 1,125 ms (1,094–1,145). 8.1–8.3 pass.
- Scrolling quickly through the 5 MB file was smooth, with no spinning
  cursor (8.3).
- All of spec section 8 passes, so 7.2 is ticked.

**Next**
- 7.3: privacy check (network monitor, entitlements, the only package).

## 2026-11-05: Roadmap 7.1, performance and edge fixtures, timing script

**Done**
- `fixtures/typical.md` (49 KB): a made-up README for a command-line
  tool. It has headings, lists, 22 command sections, 28 tables, 67 code
  blocks in several languages, a task list, links and one local image.
  Its expected HTML is recorded.
- `large.md` isn't stored. The timing script makes it (5.0 MB, typical.md
  repeated 104 times) in the git-ignored `build/timing/`, so the repo
  doesn't carry 5 MB of copies. `spec.md` "Test files" now says so.
- New files in `fixtures/edge/`:
  - `bom.md`: the heading still renders
  - `utf16.md`: garbled, with the notice, as spec 10.2 says
  - `crlf.md`: the same as LF line endings
  - `control-characters.md`: NUL becomes U+FFFD
  - `unclosed.md`: emphasis, a link, an HTML comment and a fence left
    open; the comment swallows the rest as source text, as CommonMark
    says
  - `long-lines.md`: a 22 KB paragraph line and an 8 KB code line
  - `deep-nesting.md`: 1,500 nested quotes, which get the plain-text
    notice

  Their expected HTML was recorded and reviewed.
- The fixture tests now render through `renderSafely`, the app's own
  path, so a deliberately deep file can be a fixture. The "real files
  aren't flagged as deep" test skips that one file.
- `scripts/time-open.swift`: a Swift script with no extra tools. It does
  one uncounted run first, to cover the signature check after a rebuild.
  Then each run:
  - quits mdview
  - opens typical.md cold
  - opens three copies warm
  - opens the 5 MB file

  It reads the documentVisible signpost and prints each median against
  spec 8.1–8.3. CLAUDE.md and architecture.md say how to run it.

**Measurements** (the 6.6 release build, unchanged app code; load
average about 4)

| Spec | Result | Target |
|---|---|---|
| 8.1 cold, typical.md | median 503 ms (491–513, n=5) | under 500 ms: **miss** |
| 8.2 warm, typical.md | median 157 ms (129–197, n=15) | under 200 ms: pass |
| 8.3 large, 5.0 MB | median 1,162 ms (1,130–1,207, n=5) | under 2 s: pass |

- Cold open misses by a few milliseconds under this load, as earlier
  measurements predicted. Roadmap 7.2 deals with it.
- 8.3's "scrolling stays smooth" isn't measured by the script; it needs
  a hand check in 7.2.

**Not checked**
- I didn't look at the new edge files in the app window. Their HTML is
  checked, and the notices come from code tested earlier.
- A file that can't be read (spec 10.3) can't be stored in git with its
  permissions, so it stays a manual check for the 7.6 checklist.

**Next**
- 7.2: measure all of spec section 8; fix cold open and memory.

## 2026-11-05: Roadmap 6.6, code.md and a 2,000-line block (M6 done)

**Done**
- `fixtures/code.md`: one block for each of the nine languages, each
  with keywords, strings, comments and numbers (HTML has no numbers, and
  plain JSON has no comments). There are multi-line strings and comments,
  two close relatives (`JSONC` in capitals, `xml`), plain blocks (no
  tag, `cobol`, indented) and four broken blocks (an unclosed Python
  string, JS comment, template literal, and HTML attribute).
  Its expected HTML is recorded in `fixtures/expected/code.html` and was
  reviewed.
- `CodeFixtureTests`: checks code.md block by block (spec 7.1–7.4,
  7.6). The broken blocks don't spill colour into the text after them,
  and every `<span>` is closed. It also has a timing test for a
  2,025-line Swift block: it fails only above 500 ms, which in a debug
  build catches work that grows with the square of the length. The real
  check is the app timing below.
- Spec section 7 now passes as a whole, so M6 is done.

**Measurements** (Release, Apple silicon, load average about 4)

| What | Result |
|---|---|
| Render a 2,025-line Swift block (62 KB), release | median 10 ms |
| Same, debug build, tests in parallel | 69–170 ms |
| Cold open, typical files (baseline) | median 498 ms (465–541) |
| Warm open, typical files (baseline) | median 185 ms (max 197) |
| Cold open, 2,000-line code file | median 464 ms (430–495) |
| Warm open, 2,000-line code file | median 171 ms (max 178) |

- Spec 7.7 passes: the 2,000-line file opens as fast as the typical
  files. Highlighting doesn't need to move after first paint.
- The typical-file cold median, 498 ms, is right at the 500 ms limit
  again under this load, and one run reached 541 ms. That's the
  existing roadmap 7.2 problem, not something 6.6 caused.

**Not checked**
- I didn't look at code.md in the app window. Its HTML is checked, and
  roadmap 6.5 confirmed the colours apply in the app.

**Next**
- M7, starting with 7.1: `typical.md`, `large.md`, the edge fixtures and
  a timing script in the repo.

## 2026-11-05: Roadmap 6.5, code colours

**Done**
- `preview.css`: token colours as variables, GitHub's palette, set for
  light, dark and print (print always uses the light set).

| Token | Light (on #f6f8fa) | Dark (on #151b23) |
|---|---|---|
| keyword | #cf222e | #ff7b72 |
| string | #0a3069 | #a5d6ff |
| comment | #59636e | #9198a1 |
| number | #0550ae | #79c0ff |

- `Tests/MDViewCoreTests/ContrastTests.swift`: reads the real
  `App/Resources/preview.css` and checks WCAG contrast for every text
  colour against what it's drawn on, light and dark: the four token
  colours, text and muted on the code background; text, muted and links
  on the page (white / the system's dark Canvas, rgb(30, 30, 30)); text
  on striped rows. Also checks print uses the light colours.

**Checked**
- Contrast, light / dark: keyword 5.0 / 6.9, string 12.0 / 11.3, comment
  5.7 / 5.9, number 7.1 / 8.9; text, muted and link as measured in 2.8
  (15.8 / 14.1, 6.1 / 5.7, 5.3 / 5.9). All at least 4.5:1 (spec 7.5).
- In the app (temporary hook, removed): elements.md's tokens computed to
  exactly these colours in light and dark, on the expected code
  backgrounds; 10 coloured spans on the page.
- 258 tests pass; Debug and Release build with no warnings.

**Next**
- Roadmap 6.6: `fixtures/code.md`; a 2,000-line block against the speed
  targets.

## 2026-11-05: Roadmap 6.4, code blocks coloured by language tag

**Done**
- `Languages.rules(forTag:)`: the fence's first word (lowercased) picks
  the rules. Spec 7.1's tags: `swift`; `python`/`py`;
  `javascript`/`js`/`jsx`; `typescript`/`ts`/`tsx`; `sh`/`bash`/`zsh`/
  `shell`; `json`; `yaml`/`yml`; `html`; `css`. Plus close relatives using
  the same rules: `mjs`, `cjs`, `jsonc`, `htm`, `xml`, `svg`.
- The renderer colours code blocks with a known tag; untagged, unknown
  (`text`, `cobol`, …) and indented blocks stay plain, escaped (spec 7.4).
  Inline code is never coloured.
- `elements.md` expected HTML re-recorded: the only changes are its
  Swift, Python and JSON blocks now coloured; the `text` block unchanged.
- Fixed a stale comment in `HTMLRenderer` (it still said images showed
  alt text only).

**Checked**
- 9 new tests (254 total): every listed tag colours a keyword; tag case
  doesn't matter; relatives work; untagged/unknown/indented stay plain and
  escaped; inline code never coloured; code inside lists and quotes
  coloured; only the info string's first word counts.
- Speed (release): one 2,000-line Swift block renders in 23 ms; the 5 MB
  worst case with a Swift block in each of ~19,000 sections went from
  1,133 to 1,247 ms.
- App builds with no warnings. **No colours show yet**: the token colours
  are roadmap 6.5.

**Next**
- Roadmap 6.5: light and dark token colours with 4.5:1 contrast.

## 2026-11-05: Roadmap 6.3, shell, JSON, YAML, HTML, CSS

**Done**
- Two small additions to `LanguageRules`, needed for HTML:
  - a string style can be limited to starting after a given character
    (`onlyAfter`): HTML strings only after `=`, so attribute values are
    strings but an apostrophe in text ("Don't") isn't;
  - `tagNamesAreKeywords`: a word right after `<` or `</` is coloured as a
    keyword, so tag names are coloured without colouring "a" or "p" in
    text.
- Tables in `Languages.swift`:
  - **Shell**: keywords and common built-ins; `#` only at the start of a
    word (`$#`, `${#x}`, `a#b` aren't comments); both quotes span lines;
    `-` is part of a word (`--if-needed` isn't a keyword).
  - **JSON**: `true`/`false`/`null`, strings, numbers; `//` and `/* */`
    comments tolerated (common in config files).
  - **YAML**: booleans and null in their usual spellings, `#` after a
    space, both quotes. Approximation: the doubled-quote escape `'it''s'`
    shows as two strings side by side.
  - **HTML**: `<!-- -->`, tag names (incl. custom elements), attribute
    values; numbers off so text stays plain.
  - **CSS**: `/* */`, strings, numbers with units (`600px`, `1.5rem`),
    at-rules and a few value keywords (`!important`, `auto`, `none`,
    `inherit`, …); `#` in words so hex colours and ids stay whole.

**Checked**
- 14 new tests (245 total): a realistic snippet per language with the
  exact tokens expected, the tricky cases above, and 300 random inputs
  for each of the nine languages keeping exactly their text.
- Not used by the renderer yet (6.4).

**Next**
- Roadmap 6.4: language tags and aliases; untagged and unknown blocks stay
  plain.

## 2026-11-05: Roadmap 6.2, Swift, Python, JavaScript, TypeScript

**Done**
- `MDViewCore/Highlighter/Languages.swift`:
  - **Swift**: reserved words plus common contextual ones (`async`,
    `await`, `some`, `any`, `mutating`, `get`/`set`, …); `//`, nesting
    `/* */`; `"…"`, `"""…"""`, raw `#"…"#` and `#"""…"""#`.
  - **Python**: all keywords incl. `match`/`case`/`type`; `#`; single,
    double and triple-quoted strings (a prefix like `f` or `r` stays
    plain, the string is coloured).
  - **JavaScript**: keywords; `//`, `/* */`; single and double quotes,
    and template literals over several lines; `$` is part of names.
  - **TypeScript**: JavaScript plus `interface`, `type`, `readonly`,
    `keyof`, the built-in type names, and the rest of its keywords.
  - Not handled, by design (ADR 0004): JavaScript regular expression
    literals, string interpolation contents, type and function names.

**Checked**
- 12 new tests (231 total): a typical snippet per language with the exact
  keywords, strings, comments and numbers expected (Swift interpolation
  stays inside its string; Python docstring over two lines; JS template
  over a line break; `$`-names; TypeScript words not coloured as
  JavaScript); raw and multi-line strings; nested comments; type names
  not keywords; `#` inside a Python string not a comment; an unclosed
  template; and 300 random inputs per language keeping exactly their text.
- Not used by the renderer yet (6.4).

**Next**
- Roadmap 6.3: shell, JSON, YAML, HTML, CSS.

## 2026-11-05: Roadmap 6.1, the highlighter's scanner

**Done**
- `MDViewCore/Highlighter/LanguageRules`: per-language table: keywords;
  line comments (optionally only at a word's start, for shell `#`);
  block comments (optionally nesting, for Swift); string styles (open,
  close, escape character, whether they span lines; longest opener
  first so `"""` wins over `"`); extra word characters (`$`, `-`); and
  whether to colour numbers.
- `MDViewCore/Highlighter/Highlighter`: one pass over the code's Unicode
  scalars. At each position: block comment, line comment, string, number,
  word (keyword or not), else one character. Every branch moves forward;
  a debug assert plus a release fallback step guarantee it can't stall
  (spec 7.6). Output: `<span class="tok-keyword|string|comment|number">`,
  everything HTML-escaped. Numbers: decimal, `0x`/`0o`/`0b`, `_`,
  fractions, exponents, short suffixes (`10px`, `3n`, `1.5f`), never
  inside a word (`x1`), not swallowing a following method (`1.description`).
  An unclosed one-line string stops at the end of its line; an unclosed
  multi-line string or block comment runs to the end of the block.

**Checked**
- 22 new tests (219 total) using a made-up language with every rule:
  each token kind; keywords only as whole words; nesting; escapes; 12
  number forms; unicode; escaping; every malformed case; tiny and odd
  inputs; 5,000 lines of unclosed openers under 1 s; and, over 500 random
  inputs, the visible text always equals the input exactly (nothing
  added, dropped or changed).
- Speed: 2,000 lines (134 KB) in 22 ms (release), 122 ms (debug).
- Not yet used by the renderer (6.4) and no real languages yet (6.2, 6.3).

**Next**
- Roadmap 6.2: rule tables for Swift, Python, JavaScript/TypeScript.

## 2026-11-05: Roadmap 5.7, keyboard and VoiceOver; M5 done

**Found and fixed**
- When a file opened, keyboard focus was on the window, not the page, so
  arrows and Space did nothing until you clicked. The page now takes focus
  when it first appears, unless something else (the find field) has it.
- Tab didn't move through links. Turned on WebKit's `tabFocusesLinks`.

**Checked** (temporary hook sending real key events, removed)
- Focus on open: the web view. Space: scrolled 0 → 648 px with no click.
- links.md: Tab, Tab, Tab moved through the first three links in order;
  Shift-Tab, Shift-Tab went back; Return on "Jump to the end" scrolled to
  the end (0 → 779 px).
- Folder bar buttons are focusable.
- An earlier run of the Return check on elements.md followed its first
  link, so it most likely opened https://example.com in the default
  browser (harmless; the redo used a same-page link).
- 197 tests pass; Debug and Release build with no warnings.
- **Timing:** warm opens measured slower than in 3.5 (median 173–195 ms,
  slowest up to 217 ms, against 131 ms then). Turning each of the two
  changes off made no difference, and builds of earlier commits made
  today were as slow or slower (end of M3: 191 ms median, slowest 203;
  task 5.1: 195 / 230; now: 173 / 183). So it's the machine, not this
  change. Warm opens sit close to the 200 ms target (spec 8.2) in every
  version; to look into in roadmap 7.2. Cold median ~470 ms.

**Not checked automatically: VoiceOver itself.** WebKit builds the
accessibility tree only when an assistive app connects, and reading it
from outside needs Accessibility permission this shell doesn't have. The
page uses the HTML VoiceOver relies on (headings, links, image alt text
or `role="img"` placeholders, checkboxes, table headers). To check:
turn on VoiceOver (⌘F5), open `fixtures/elements.md`, use the rotor
(VO-U) to list headings and links; images should read their alt text and
task items "checkbox, checked/unchecked".

**M5 is done.** Still to try by hand: VoiceOver as above, the Window
menu's tab commands, ⌘-click on the title, the print panel, and picking
an editor in the app picker.

**Next**
- Roadmap M6, task 6.1: the code highlighter's scanner.

## 2026-11-05: Roadmap 5.6, windows, tabs, copying, restoration

No code changes were needed; this was checking. (Temporary hooks,
removed.)

**Checked**
- **6.1** Each window is titled with its file name and represents its
  file (`representedURL`), which gives the title bar its proxy icon and
  ⌘-click path menu.
- **6.2** Windows use automatic tabbing with a shared tab identifier;
  Window ▸ Merge All Windows put two files into 2 tabs of one window.
- **6.5** Selecting the first heading and Edit ▸ Copy put plain text
  ("Valid") on the clipboard, plus rich text, HTML and a web archive for
  apps that want them. The clipboard was saved first and restored
  exactly afterwards.
- **6.13** Opened two files, used the app, switched away, force-quit,
  relaunched with no file: both windows came back, and **no Open panel**
  appeared over them (the open question from 1.6). A fresh launch with
  nothing to restore shows the Open panel; after an ordinary quit, with
  macOS's default "Close windows when quitting", nothing is restored and
  the panel shows. Spec 6.13 now describes this.
- Debug and Release build with no warnings.

**Found**
- macOS saves window state while the app is active or as you switch away.
  My first restoration tests launched MDView in the background and never
  made it active, so nothing was saved; one even restored a file from an
  earlier session of yours instead. Not a bug in MDView.

**Not checked** (needs a person)
- The tab commands (Show Tab Bar, Merge All Windows, …) appearing in the
  Window menu: macOS inserts them only when the menu opens.
- ⌘-click on the window title for the path menu.

**Next**
- Roadmap 5.7: keyboard and VoiceOver pass.

## 2026-11-05: Roadmap 5.5, Open in Editor

**Done**
- `App/EditorLauncher.swift`: the chosen editor saved as a bookmark
  (still works if the app is moved). If it can't be found it's forgotten
  and the picker comes back (spec 6.12).
- Picker: app-only `NSOpenPanel` sheet starting in /Applications.
  Choosing MDView itself is refused with an explanation.
- File ▸ Open in Editor… ⇧⌘E, which reads "Open in <app>" once an editor
  is chosen (6.11), and Change Editor… Both greyed out while the file is
  gone. Opening uses `NSWorkspace.open(_:withApplicationAt:)`; errors are
  shown.

**Checked** (temporary hook, removed; saved choice cleared afterwards)

| Situation | Menu | Choosing it |
|---|---|---|
| nothing chosen | "Open in Editor…" ⇧⌘E | app picker sheet |
| TextEdit remembered | "Open in TextEdit" | TextEdit launched with the file, no picker |
| remembered app deleted | back to "Open in Editor…" | picker again |

- TextEdit (not running before) was quit afterwards. It doesn't keep the
  file open, so the shell couldn't confirm which file it showed; it was
  launched with the file handed to it.
- 197 tests pass; Debug and Release build with no warnings.
- Not checked: choosing an app in the picker by hand, and VS Code / other
  editors as the choice.

**Next**
- Roadmap 5.6: tabs, title bar path menu, window restoration, selection.

## 2026-11-05: Roadmap 5.4, Reveal in Finder

**Done**
- File ▸ Reveal in Finder ⇧⌘R (handled by the document window):
  `NSWorkspace.activateFileViewerSelecting` with the document's file.
  Greyed out while the file is gone (after the "no longer available"
  notice).

**Checked** (temporary hooks, removed)
- Menu item present with ⇧⌘R and enabled; choosing it opened a Finder
  window (Finder windows 5 → 6; it's still open on your screen).
- Finder didn't come to the front in the test because MDView was
  launched in the background and wasn't the active app; macOS only lets
  the active app hand over focus, so it will when you use the menu.
- Deleting the file greyed the item out (enabled true → false).
- 197 tests pass; Debug and Release build with no warnings.

**Next**
- Roadmap 5.5: Open in Editor and Change Editor.

## 2026-11-05: Roadmap 5.3, printing and Save as PDF

**Done**
- File ▸ Page Setup… ⇧⌘P and Print… ⌘P, handled by `NSDocument`.
  `MarkdownDocument` overrides `printOperation(withSettings:)` with
  WebKit's own print operation for the page, fitted to the page width,
  with the user's Page Setup settings. The standard print panel offers
  Save as PDF.
- (A force cast in the first version replaced with a checked cast, per
  CLAUDE.md.)

**Checked** (temporary hook, removed: printed elements.md through the
same operation, saving a PDF instead of using the panel, which is what
Save as PDF does)

| | App in light mode | App in dark mode |
|---|---|---|
| Pages | 8 × A4 (595 × 842 pt) | the same |
| Text | 3,869 characters; "Elements", "Tables (2.9)", "Heading level 6", "Straight double quotes", "The end." all present | the same |
| Each page | 94–100 % near-white, dark text | the same |

- So the print styles force black on white whatever the app's
  appearance. A copy is in the git-ignored `build/` folder
  (`elements-printed-from-dark-mode.pdf`) for a visual check.
- 197 tests pass; Debug and Release build with no warnings.
- Not checked: the print panel itself and printing to a real printer
  (needs a person).

**Next**
- Roadmap 5.4: Reveal in Finder.

## 2026-11-05: Roadmap 5.2, zoom

**Done**
- `MDViewCore/ZoomLevels`: Safari's steps (50, 67, 75, 80, 90, 100, 110,
  125, 150, 175, 200, 250, 300 %); any value moves to the next step in
  the right direction. 5 tests.
- View menu: Actual Size ⌘0, Zoom In ⌘= (plus a hidden ⌘+ so Shift-=
  works), Zoom Out ⌘−. Handled by the document window, which greys out a
  command that would do nothing (at the limits, or Actual Size at 100 %).
- Zoom is `WKWebView.pageZoom`, per window, kept through re-renders
  (file changes, folder grants). Not remembered once the window closes.

**Checked** (temporary hooks, removed)
- Steps and limits: 100 → 125 → … → 300 % (Zoom In greyed), → 100 %
  (Actual Size greyed), → 50 % (Zoom Out greyed). A second window stayed
  at 100 % throughout. Zoom stayed at 300 % after a re-render.
- It really scales: the same 860 pt window is 860 CSS px wide at 100 %,
  573 at 150 %, 286 at 300 %, 1,720 at 50 % (860 ÷ zoom). (A first check
  measured a heading's height in CSS px, which zoom doesn't change; the
  page's CSS width is the right measure.)
- 197 tests pass; Debug and Release build with no warnings.

**Next**
- Roadmap 5.3: print and Save as PDF.

## 2026-11-05: Roadmap 5.1, find

**Done**
- `App/FindBar.swift`: search field, previous/next, match count ("3
  matches" / "1 match" / "Not found", the last also announced to
  VoiceOver), Done. Typing searches from the top as you type
  (case-insensitive, wraps); Return next, Shift-Return previous, Esc
  closes and puts the focus back on the page.
- `PreviewController` implements `FindTarget`: `WKWebView.find` for the
  search; the app's own script (search text as an argument) for the
  count, clearing the selection and reading the selected text.
- Edit ▸ Find: Find… ⌘F, Find Next ⌘G, Find Previous ⇧⌘G, Use Selection
  for Find ⌘E, all handled by the document window through the responder
  chain. Find Next with nothing searched yet opens the bar.

**Checked** (temporary hook on elements.md, removed)

| Step | Result |
|---|---|
| ⌘F | bar shown, cursor in the field |
| type "table" | "3 matches", first selected (y 3546) |
| ⌘G, ⌘G | next (3776), next (5478) |
| ⇧⌘G | previous (3776) |
| type nonsense | "Not found", selection cleared |
| select "Blockquotes", ⌘E | field filled, "1 match", selected |
| menu actions | all 4 reach DocumentWindowController |
| Esc in the field | bar closed, focus back on the page |

- 192 tests pass; Debug and Release build with no warnings.
- Not checked visually (how the bar looks, light and dark).

**Next**
- Roadmap 5.2: zoom in, zoom out, actual size.

## 2026-11-05: Roadmap 4.4, real editors and save methods; M4 done

**Done**
- Installed here: vim 9.1, nano, VS Code, Xcode 26.6 / 27.0, TextEdit.
- vim driven for real (headless) in its four save modes. TextEdit and
  Xcode save through AppKit's standard document save, so a small tool
  (session scratchpad) reproduces exactly that: a new file in a
  replacement folder, then `FileManager.replaceItemAt` under a file
  coordinator. Plus other common ways files change.

**Results** (Release app, file open, saved twice each way; "shown" is
until MDView's page updated; every read matched the bytes on disk; none
was wrongly reported as gone)

| How it was saved | Shown after |
|---|---|
| vim, defaults | 97–105 ms |
| vim `backupcopy=no` (rename + new file) | 96–97 ms |
| vim `backupcopy=yes` (in place) | 42–43 ms |
| vim `nobackup nowritebackup` | 47 ms |
| TextEdit / Xcode style (`replaceItemAt`, coordinated) | 85–88 ms after the file changed |
| `sed -i` | 84–87 ms |
| `cp` over the file | 30–32 ms |
| git style (delete, then create) | 78–86 ms |
| Python `os.replace` | 82–83 ms |
| slow two-step write (250 ms apart) | 31 ms, then again for the rest |

- All under the 500 ms target (spec 5.1); save-by-replace in all its forms
  keeps working (5.3).
- The first TextEdit-style save measured 546 ms from launching the tool;
  that was macOS checking the newly built tool on its first run. Measured
  from the file's modification time it's 85–88 ms, every time.
- A slow two-step write briefly shows the half-written file, then the
  whole one. Expected: the file really was half written for 250 ms.

**M4 is done.** To try by hand (needs the editors' windows):
- Open a `.md` in MDView and in TextEdit (Format → Make Plain Text),
  VS Code and Xcode; edit and save in each; MDView should update within
  a moment and keep your scroll position.

**Next**
- Roadmap M5, task 5.1: find bar.

## 2026-11-05: App shown as "MDView"; roadmap 4.3, file gone and back

**Name**
- The owner changed the display name to **MDView** in Xcode (Xcode also
  dropped the entitlements file from the synced group's exception list;
  checked: the built app has no stray file and the same entitlements).
  Menus (About / Hide / Quit MDView), the folder bar and picker message,
  and error notices now say MDView; spec, README and vision updated.
  Project, code, bundle ID and file names stay `mdview`.

**4.3 Done**
- When the watcher reports the file gone, the window keeps the last
  content and shows "“note.md” is no longer available. You're seeing the
  last version; it will update if the file comes back." (also announced
  to VoiceOver). When the file is back, the notice goes and the new
  content shows.
- Tried following a coordinated (Finder-style) move to its new name;
  AppKit didn't update the document's URL, and spec 5.4 treats "moved
  away" as gone anyway, so that code was removed. Noted under "After v1".

**Checked** (temporary hook, removed; file in `~/Library/Caches`)

| Event | Window |
|---|---|
| deleted | notice, last content kept |
| recreated | notice gone, new content |
| `mv` away / back | notice / gone |
| coordinated move away / back | notice / gone |
| edited after coming back | updates (still watched) |

- 192 tests pass; Debug and Release build with no warnings.

**Next**
- Roadmap 4.4: try it with real editors (TextEdit, Xcode, VS Code, vim).

## 2026-11-05: Roadmap 4.2, keeping your place on reload; changed images

**Done**
- After the first load, a re-render (file changed, or a folder grant)
  swaps the page body in place with the app's own script, the HTML passed
  as an argument; page JavaScript stays off. Scroll position is kept
  (spec 5.2). Renders are numbered so a slow older one never replaces a
  newer one; a failed swap falls back to loading the page.
- Image URLs now carry the image file's modification time (`?v=…`): a
  changed image is fetched again on the next render, unchanged ones stay
  in WebKit's cache (spec 5.5). The scheme handler only looks at the path.

**Checked** (temporary hook, removed; long test page scrolled to 3,000 px)

| Edit from outside | scrollY | Content | Image |
|---|---|---|---|
| none | 3000 | 201 paragraphs | 48 px, v=…358 |
| append at end (in place) | 3000 | 202, new last line | same version (cached) |
| 10 lines inserted at top (replace) | 3000 | 212, new title | same version |
| image file swapped, page re-saved | 3000 | 213 | **2400 px, v=…433** |

- Reload speed with a 50 KB file: 59–62 ms in place, 112–116 ms save by
  replace (target < 500 ms).
- 192 tests pass; Debug and Release build with no warnings.
- Not checked: a page that gets much shorter (the browser keeps the scroll
  within the new length; spec 5.2 "as close as the new content allows").
  An image that changes *without* the page being saved isn't noticed until
  the page's next reload; spec 5.5 only asks for that.

**Next**
- Roadmap 4.3: the file disappearing and coming back.

## 2026-11-05: Roadmap 4.1, watching files for changes

**Done**
- `MDViewCore/Files/FileWatcher` (no AppKit, so unit tested):
  `DispatchSource` on the file for write/extend/delete/rename/revoke/link.
  Bursts debounced to one `.changed` after 50 ms. After a delete or
  rename it looks for a file at the path every 50 ms for up to 1 s
  (save-by-replace), then reports `.disappeared` once and polls every
  second until the file returns (`.changed`). Events on its own serial
  queue; `stop()` guarantees no more events.
- `MarkdownDocument` owns a watcher from its window opening until it
  closes; on `.changed` it re-reads with `revert(toContentsOf:)` and the
  window renders again. `.disappeared` is only logged for now (notice in
  4.3). Scroll position isn't kept yet (4.2).

**Checked**
- 8 watcher tests with real files: in-place write reported < 500 ms; 10
  quick writes → exactly one change; save-by-replace twice then in place
  → three changes; three `.atomic` writes → three; delete → disappeared,
  recreate → changed, then watched again; moved away and back; nothing
  after `stop()`; starting on a missing file waits for it. Ran 4 times,
  stable (8 s per run, mostly deliberate waits).
- In the app (Release, file in `~/Library/Caches`): saved from outside 9
  times. Window updated after **39–41 ms** (in place), **92–96 ms**
  (rename over), **89–94 ms** (atomic replace); target < 500 ms (spec
  5.1). Every save was seen, including repeated replaces (re-watching
  works in the sandbox, spec 5.3), and each read had the new byte count.
- 192 tests pass; Debug and Release build with no warnings.

**Next**
- Roadmap 4.2: keep the scroll position on reload; refresh changed
  images.

## 2026-11-05: Roadmap 3.6, images and links test files; M3 tasks done

**Done**
- `fixtures/images.md`: 13 local images (relative, `./`, `../`, space
  encoded and in angle brackets, with title, no alt, small, wide, in a
  link, table, list and quote) and 6 that must never show (missing, a
  Markdown file, https and http remote, `javascript:`, `data:`).
  Added `images/wide.png` (2400 × 300) and `images/with space.png`.
- `fixtures/links.md`: 20 links covering anchors, other Markdown files,
  other files and folders, web, mail, bare and angle-bracket addresses,
  reference links, missing files; plus 3 unsafe links shown as text.
  Added `edge/with space.md`.
- `FixtureDrivenTests`: images.md rendered as if granted gives exactly
  13 `<img>` and the 6 expected placeholders; without access, 19
  placeholders. Every link in links.md goes through `LinkRoute` as a
  click would and gives the expected route; linked files exist except the
  "missing" ones; images the file expects exist.
- `<img>` now has `decoding="async"` so decoding a big image never holds
  up the text (spec 3.7).
- Expected HTML recorded for images.md, links.md and edge/with space.md.
  The placeholders' hover text shows the source as written, including
  `javascript:`/`data:`, as plain attribute text (never a src or href).

**Checked**
- 184 tests pass; Debug and Release build with no warnings.
- In the app with a temporary hook (removed), after granting the three
  image files: images.md showed 13 images, all loaded; the small one at
  its natural 48 px; the wide one 2400 px scaled to the 781 px column;
  6 placeholders; no sideways page scroll (spec 3.4).

**M3 status:** all six tasks done. Still to check by hand (each needs a
person or would open other apps):
- Choosing a real folder in the picker (spec 9.5, 9.6), then reopening.
- Clicking web and mail links in `links.md` (4.1).
- A missing file inside a granted folder shows the notice (4.6).
- An image or folder link opening in Preview / Finder (4.4).
- Hover tooltips on links (4.5).
To try them: `open -a build/mdview.app fixtures/links.md`, click
Allow… and choose the `fixtures` folder, then click through the list.

**Next**
- Roadmap M4, task 4.1: `FileWatcher`.

## 2026-11-05: Roadmap 3.5, link clicks

**Done**
- `MDViewCore/Files/LinkRoute`: pure decision for a clicked URL:
  external (http, https, mailto), open Markdown (+ fragment), open other
  file, scroll in page, or ignore. 20 tests (relative, `../`, all four
  Markdown extensions, anchors, own file with/without anchor, spaces and
  accents, `file:` URLs, folders, unknown schemes).
- Page base URL is now `mdview-file://document/<document folder>/`
  (symlinks resolved), so WebKit resolves relative and `../` links into
  real paths.
- `PreviewController`: routes only real link clicks; allows our own page
  loads; cancels everything else. Cmd-click / `target=_blank` routed the
  same way. `scroll(toFragment:)` scrolls to a heading with the app's own
  script, the id passed as an argument (never run as code).
- `DocumentWindowController`: carries out the route; asks for folder
  access first when needed (picker refactored to be reusable); brief
  self-dismissing notice for a missing file, also announced to VoiceOver.

**Found and fixed while testing**
1. The page's own load was cancelled: WebKit asks for permission more
   than once per load, and a "allow the next load" flag only covered the
   first ask. Pages were blank. Now any load of the page's exact base URL
   is allowed.
2. **A folder picker could pop up when simply opening a file**, and cold
   opens rose to ~1,050 ms: WebKit also asks about the spare's blank page
   (`mdview-file://document/`), which was routed like a link to "/" and
   started a folder picker. Now only real clicks are routed. Cold open
   back to a 454 ms median.
3. `/tmp` vs `/private/tmp`: document and page paths now both have
   symlinks resolved, so "this page" is recognised.

**Checked** (temporary hook clicking links with the app's own script,
removed; web and mail links not clicked, so the browser wasn't opened)
- On open: no sheet. `#target` on the page: scrolled (4,528 px).
- `page2.md#target` (granted): opened, front, scrolled so the heading
  sits 16 px from the top (the CSS scroll margin).
- `valid.md` (granted): opened in mdview, front.
- Link outside granted folders: folder picker sheet.
- 178 tests pass; Debug and Release build with no warnings.
- Timing after the fixes (load average ~4): cold median 454 ms (first
  launch after rebuild 844 ms), warm median 131 ms.
- **Not tested:** clicking web/mail links (would open your browser and
  mail app), a missing file in a granted folder (needs a real folder
  grant), opening a non-Markdown file in its default app, Cmd-click.
  Spec 4.5 (tooltip with destination) comes from the `title` attribute
  added in 2.7; not checked visually.

**Next**
- Roadmap 3.6: `fixtures/images.md` and `fixtures/links.md`.

## 2026-11-05: Roadmap 3.4, proving the page stays offline

**Done**
- `MDViewCore/PageSecurity`: the block list, its ID, the page's Content
  Security Policy and the scheme name, as plain values. The app's web
  view setup and page shell use them, so tests check exactly what ships.
- `Tests/MDViewCoreTests/OfflineProtectionTests.swift`: a real WKWebView
  in the test process, set up like the app (JavaScript off,
  non-persistent store, our scheme). The page tries every kind of remote
  load: stylesheet, favicon, CSS background, web font, script tag, inline
  script with `fetch`, image, `<picture>` source, iframe, video, audio,
  object. They all point at a tiny HTTP server on 127.0.0.1 that counts
  requests, so the test never leaves this Mac.
- Spec 9.8: a failure preparing the block list now always shows
  mdview's own message ("mdview couldn't set up its offline protection,
  so this file isn't shown.") and logs the cause; before, a compile error
  showed WebKit's raw "WKErrorDomain error 6".
- Remote images as placeholders (spec 3.5) were done in 3.3.

**Checked**
- Offline tests (each a separate web view and server):

| Setup | Requests reaching the server |
|---|---|
| Block list only | 0 |
| Security policy only | 0 |
| Both (as in the app) | 0 |
| Neither (control) | > 0, so the test does see leaks |

- Page script never ran (marker text unchanged); the block list compiles.
- In the app with a temporary switch that compiled a broken block list
  (removed): no web view created, no page shown, the message shown, the
  cause logged. Normal launch still shows the page.
- 166 tests pass (4 s, mostly the web view tests); Debug and Release
  build with no warnings.
- Not here: watching real network traffic with a monitor (roadmap 7.3).

**Next**
- Roadmap 3.5: `LinkRouter`, what clicking a link does.

## 2026-11-05: Roadmap 3.3, local images

**Done**
- Renderer: images go through an `ImageLocator` (closure supplied by the
  app). A local image it approves becomes `<img src alt [title]>`;
  anything else (missing, not granted, remote, `javascript:`, `data:`)
  becomes `<span class="image-placeholder" role="img">alt text</span>`
  (file name if there's no alt text). Remote images are never fetched, so
  that part of 3.4 is done.
- `App/AssetSchemeHandler.swift`: serves `mdview-file://document/<path>`
  only for image files inside a granted folder (checked again, even
  though the renderer already checked); reads off the main thread; MIME
  type from the extension; ignores cancelled requests.
- `ImageAccess`: the app's locator (resolves against the document; image
  type, exists, granted) using a value snapshot of the grants so it runs
  safely on the render thread.
- `elements.md` expected HTML re-recorded: the only change is its two
  images, now placeholders (the tests render without the app's locator).

**Checked**
- 160 tests pass (10 new image tests: img for available, placeholder for
  missing/remote/unsafe, title kept, alt from formatting, file name when
  no alt, escaping, image inside a link, locator asked with the source as
  written).
- In the app with a temporary hook (removed), granting
  `fixtures/images/sample.png` (a file macOS had given access to):
  - Before: all 6 images on a test page were placeholders.
  - After, relaunched: absolute path, `file://` URL and relative path all
    loaded as the real 48 px image; missing, ungranted and remote stayed
    placeholders.
  - In the same session: with the page already open, granting made all 3
    images appear without reopening (spec 9.5).
  - Test grant cleared afterwards.
- Debug and Release build with no warnings.
- Not checked visually; image sizing relies on `img { max-width: 100% }`
  (spec 3.4) from 2.8.

**Next**
- Roadmap 3.4: automated test that the block list stops remote loads, and
  refusing to show a page if the list fails to load.

## 2026-11-05: Roadmap 3.2, folder access bar and picker

**Done**
- Renderer now also returns the page's **local references**
  (`RenderedPage.localReferences`): image sources and link destinations
  that are relative paths, absolute paths or `file:` URLs, in order,
  without repeats. Not `#anchors`, web, mail or unsafe links.
- `MDViewCore/Files/LocalReferences`: resolves a reference against the
  document (percent-encoded or plain, `file:` URLs, drops `#fragment` and
  `?query`); suggests the closest folder holding the document and every
  file it needs (`../images/a.png` → the folder above).
- `PreviewController`: after each render, works out which references
  aren't the document itself and aren't in a granted folder, and reports
  the folder to offer (or none). New `reload()` re-renders in the same
  web view.
- `DocumentWindowController`: the bar "Allow mdview to show images and
  linked files in this folder." with **Allow…** and **Not Now** (spec
  9.5, 9.7). Allow… opens the standard folder picker as a sheet at the
  suggested folder; any folder can be chosen (the message explains a
  higher folder covers more). After a grant, `FolderAccess` posts a
  notification and every window that needed something re-renders, so
  nothing has to be reopened. Not Now hides the bar for that window.
- Images still show alt text until 3.3, so a grant doesn't visibly change
  them yet; links to other files work once 3.5 lands.

**Checked**
- 150 tests pass (8 new: references collected in order without repeats
  and without web/mail/anchor/unsafe links; elements.md's 3 references;
  resolving 10 kinds of reference; suggested folder cases).
- In the app, with a temporary hook (removed): elements.md showed the bar
  with both buttons; valid.md (no references) showed none; latin1.md
  only its UTF-8 notice. Allow… put an `NSOpenPanel` sheet on the
  window; closing it left the bar; Not Now removed it.
- Debug and Release build with no warnings.
- **Not tested: actually choosing a folder** (needs a person at the
  picker). To try: open `fixtures/elements.md` with `build/mdview.app`,
  click Allow…, choose the `fixtures` folder. The bar should disappear,
  and stay away after quitting and reopening the file.

**Next**
- Roadmap 3.3: `AssetSchemeHandler` serving local images.

## 2026-11-05: Roadmap 3.1, remembering folder grants

**Done**
- `MDViewCore/Files/FolderGrantList`: pure rules for which folders are
  granted. A grant covers the folder and everything inside; "/a/bc" isn't
  inside "/a/b"; granting a covered folder does nothing; granting a
  folder above existing grants replaces them. 8 tests.
- `App/FolderAccess.swift`: saves each grant as a security-scoped
  bookmark in the app's settings; at launch resolves them, starts access
  for the session, refreshes stale bookmarks and drops ones that no
  longer resolve. Paths are compared after resolving symlinks. Logs
  counts only, no paths.
- Restored in `applicationWillFinishLaunching`, before any file opens.
- New entitlement `com.apple.security.files.bookmarks.app-scope`
  (needed for bookmarks; ADR 0005 already planned them).
- Architecture: `MDViewCore` now also holds logic that needs no AppKit
  or WebKit (like these path rules), so it can be unit tested.

**Checked**
- 142 tests pass; Debug and Release build with no warnings; Release
  entitlements: sandbox, user-selected read-only, app-scoped bookmarks,
  network client.
- End to end with a temporary hook (removed): the folder picker comes in
  3.2, so this used a file macOS had already given access to.
  - Before any grant: `plain.txt` and `valid.md` both **denied** by the
    sandbox.
  - Opened `plain.txt` and granted it; quit.
  - Relaunched with nothing opened: `plain.txt` covered and **read
    (72 bytes)**; `valid.md` still denied. Log: "restored 1 of 1".
  - Test grant cleared afterwards.
- Not tested: a real folder grant (needs 3.2's picker), and a stale
  bookmark being refreshed.
- Known limit: ad hoc signed builds can't use bookmarks from a previous
  build, so rebuilding forgets grants (same as the recent-files list).

**Next**
- Roadmap 3.2: the folder access bar and picker; reload images once
  granted.

## 2026-11-05: Roadmap 2.10, expected HTML recorded; M2 done

**Done**
- Owner looked over `elements.md` and `front-matter.md` in the app
  (light and dark): looks good.
- Recorded expected HTML for all 6 fixtures in `fixtures/expected/`
  (`elements.html` 8,856 bytes, `front-matter.html`, and the 4 edge
  files). From now on any rendering change shows up as a test failure
  until it's re-recorded on purpose.
- M2 is done: every spec section 2 criterion is rendered and tested.

**Checked**
- Recorded HTML contains only mdview's own tags (the 3 `<div>`s are
  table wrappers); no `<script>`, `<style>`, `<iframe>`, `<img>`,
  `<span>` or `<b>` from the sources.
- Normal test run compares against them: 134 tests pass (6 fixture
  comparisons).

**Memory** (Release, one file open plus the 9 MB spare, each process
added up after 12 s, 3 runs each; machine quieter now, load average 3,
so runs agree within 2 MB)

| File | Total | Page process |
|---|---|---|
| valid.md (79 bytes) | 71 MB | 19 MB |
| prose.md (50 KB) | 95–98 MB | 45 MB |
| elements.md (6 KB, every element) | 98–100 MB | 47 MB |
| typical.md (50 KB, lists/tables/code) | **118–119 MB** | 63 MB |

- **Spec 8.5 (< 100 MB) fails for typical.md and is borderline for the
  others.** Up from 2.6 (page process 49 MB then), most likely from 2.8's
  16 px text and larger default window (more for WebKit to draw).
- About 70 MB is fixed before any content: app 26, GPU 13, networking 4,
  an empty page 19, the spare 9. That leaves ~30 MB for content.
- Not fixed here: noted as options under roadmap 7.2 (drop the refilled
  spare, trim WebKit's per-page memory, or revisit the target). Needs a
  decision then.

**Next**
- Roadmap M3, task 3.1: `FolderAccess`, saving and restoring folder
  grants.

## 2026-11-04: Roadmap 2.9, fuzz testing (found 2 crashes and 2 hangs)

**Found and fixed**
1. **Crash: deep nesting.** 1,000 nested quotes, 1,000 nested lists or
   10,000 `*` crashed (stack overflow) *inside swift-markdown's parser*,
   on the 512 KB stack Swift tasks get, which is where the app rendered.
   - Markdown now renders on a dedicated thread with a 64 MB stack
     (`HTMLRenderer.renderSafely`). Measured safe to 20,000 levels;
     80,000 quotes or 100,000 `*` still crash there.
   - `NestingGuard`: a quick byte scan estimates the deepest nesting
     (`>` and list markers at line starts, indentation, the longest run of
     `* _ ~`). Over 1,000 levels, the file is shown as plain text with a
     notice. All fixtures estimate under 50.
2. **Hang: deep lists.** 3,000 nested lists took 7.3 s to render
   (2,000: 3.1 s). Cause: mdview's tight/loose list check followed each
   list's last block down to the bottom, quadratic in depth. Now it only
   looks when something follows. 2,000 levels: 19 ms.
3. **Hang: long first line.** A file of 100,000 spaces took 17.7 s in
   front matter detection (trimming a long line one character at a time).
   Lines over 64 bytes can't be a fence, and line ends are found by
   searching bytes. Now well under 100 ms; regression test added.

**Done**
- `Tests/MDViewCoreTests/FuzzTests.swift` (seeded, reproducible): 600
  random Markdown fragments, 200 random byte strings (incl. invalid
  UTF-8), 300 random mutations of `elements.md`, every `.md` fixture cut
  at about 400 points, 28 pathological inputs (all the above plus huge
  tables, 1 MB lines, unclosed fences and front matter, control
  characters, 50,000 combining marks, …). Each input must render
  something (unless it's blank or only front matter) in under 2 s, via
  the same `renderSafely` the app uses. Plus checks that the guard
  catches the crash cases and doesn't flag real files.
- App uses `renderSafely`; notice style in `preview.css`.

**Checked**
- 134 tests pass: 1.4 s debug, 0.5 s release.
- In the app (Release): opened 6 pathological files at once (1,000 and
  100,000 quotes, 3,000 lists, 10,000 `*`, 100,000 spaces, 900 quotes):
  no crash, all 6 read and shown, no crash reports.
- Timing unchanged on a busy machine (load average 9): cold median
  485 ms (one run 554 ms), warm median 158 ms (max 185 ms).

**Next**
- Roadmap 2.10: look over `elements.md` and `front-matter.md` in the app
  (light and dark), then record their expected HTML. Needs the owner's
  eyes.

## 2026-11-04: Roadmap 2.8, the stylesheet

**Done**
- `preview.css` rewritten and organised by section (colours, page, text,
  lists, quotes, code, tables, shown-as-text, printing), with each rule
  tied to its spec criterion.
- Body text: system font at **16 px** (was the macOS body style, 13 px:
  meant for controls and small for reading; GitHub uses 16 px). Spec 6.3
  updated.
- Links: macOS link colours `#0068DA` / `#419CFF` (CSS `LinkText` turned
  out to be old browser blue `#0000EE`, and pale in dark mode). Spec 2.11
  updated.
- Added: heading `scroll-margin-top` (for `#anchor` jumps), images never
  wider than the column, task checkbox accent colour, tab size 4, print
  styles (always light colours even in dark mode, full width, code
  wrapped, blocks not split across pages).
- No white flash in dark mode: the spare's blank page uses the system
  background, and a brand-new web view stays hidden until its page has
  loaded.
- Default window 860 × 720 (was 760 × 680) so the full 80-character
  column fits.

**Checked** (temporary in-app style dump in light and dark, removed)
- Page background: white / rgb(30, 30, 30). Body 16 px system font.
- Contrast of every text colour on its background, light / dark:
  body 15.8 / 14.1, links 5.3 / 5.9, muted text (quotes, h6, HTML
  source) 6.1 / 5.7, code 14.8 / 14.7, code blocks 5.7 / 5.9, striped
  rows 14.8 / 14.7. All above 4.5:1.
- Column: 80 characters = 781 px; widened the default window to fit.
- Spec 2.8 and 2.9 confirmed: the long code line (1,443 px of content in
  a 687 px box) and the wide table (1,196 in 687) scroll inside their own
  boxes, and the page itself never scrolls sideways.
- Live switching when the system appearance changes: comes from
  `prefers-color-scheme`; the dump switched the web view's appearance and
  colours followed. Printing not tried.
- 124 tests pass; Debug and Release build with no warnings.

**Next**
- Roadmap 2.9: fuzz test (random and truncated input never crashes or
  hangs).

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
