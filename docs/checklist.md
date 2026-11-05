# Release checklist

Every acceptance criterion in [spec.md](spec.md), with how it's checked.
Run it before each release (roadmap 7.6). Most criteria are covered by
tests or scripts; the rest need a person at the Mac, because they involve
Finder, other apps, the pointer or VoiceOver.

**How to run the automatic part**, from the repository root, with a
release build copied to `build/mdview.app`:

```bash
swift test --package-path Packages/MDViewCore
swift scripts/time-open.swift
zsh scripts/check-offline.zsh
```

**Hand checks** are marked ✋ below; the steps are at the end. The
"Last checked" column says when and how each one last passed.

Key: **T** = unit tests (`swift test`), **S** = a script, **A** = checked
in the app during a roadmap task (see progress.md), ✋ = by hand.

## 1. Opening files

| AC | How | Last checked |
|---|---|---|
| 1.1 Open With lists MDView | S: `NSWorkspace.urlsForApplications` for `.md`, `.markdown`, `.mdown`, `.mkd` | 7.6: all four |
| 1.2 Can be the default app | ✋ 1 | 7.6 (owner) |
| 1.3 File → Open… | A (1.4) | 1.4 |
| 1.4 Several files, one window each | A, and S: `check-offline.zsh` opens 18 | 7.6: 18 windows |
| 1.5 Drop on the Dock icon | ✋ 2 | 7.6 (owner) |
| 1.6 Already open → brought forward | A (1.6), S: `time-open.swift` relies on it | 1.6 |
| 1.7 Open Recent, Clear Menu | A (1.4) | 1.4 |
| 1.8 No file → Open panel, no empty window | A (1.4, 5.6) | 5.6 |

## 2. Rendering Markdown

| AC | How | Last checked |
|---|---|---|
| 2.1–2.15 Each element | T: element tests and `fixtures/expected/*.html` | 7.6: 264 tests pass |
| 2.8, 2.9 Sideways scrolling boxes | A (2.8): measured in the app | 2.8 |
| 2.16 `elements.md` complete | T: `elements.html`; A (2.10) looked over in light and dark | 7.6 |

## 3. Images

| AC | How | Last checked |
|---|---|---|
| 3.1, 3.2 Relative, absolute, `file://` | T: `ImageTests`, `FixtureDrivenTests`; ✋ 3 with a real grant | 7.6 (owner) |
| 3.3 Formats | T: type check; A (3.3) | 3.3 |
| 3.4 Wide images scale down | A (3.3): `wide.png` | 3.3 |
| 3.5 Remote image → placeholder | T; S: `check-offline.zsh` | 7.6 |
| 3.6 Missing image → placeholder | T | 7.6 |
| 3.7 Images don't delay text | A (3.6) | 3.6 |

## 4. Links

| AC | How | Last checked |
|---|---|---|
| 4.1 Web and mail links → default app | T: `LinkRouteTests`; ✋ 4 | 7.6 (owner) |
| 4.2 Other Markdown files | T; A (3.5) | 3.5 |
| 4.3 Anchors, `other.md#section` | T: slugs and routes; A (3.5) | 3.5 |
| 4.4 Other local files → default app | T; ✋ 4 | 7.6 (owner) |
| 4.5 Hover shows destination | ✋ 4 | 7.6 (owner) |
| 4.6 Missing file → "File not found" | T; ✋ 4 | 7.6 (owner) |

## 5. Automatic reload

| AC | How | Last checked |
|---|---|---|
| 5.1, 5.3, 5.4 Saves, save-by-replace, deleted and back | T: `FileWatcherTests` (real files) | 7.6 |
| 5.2 Scroll position kept | A (4.2) | 4.2 |
| 5.5 Changed image refreshes | A (4.2) | 4.2 |
| 5.1–5.3 With real editors | A (4.4): vim, sed, cp, git-style and TextEdit/Xcode-style saves, all under 110 ms; ✋ 5 the editors' own windows | 7.6 (owner) |

## 6. Windows and appearance

| AC | How | Last checked |
|---|---|---|
| 6.1 One window per file, titled | A (5.6) | 5.6 |
| 6.1 ⌘-click title → path menu | ✋ 6 | 7.6 (owner) |
| 6.2 Merge All Windows, tabs | A (5.6) merged 2 files; ✋ 6 for the menu items | 7.6 (owner) |
| 6.3 Font, 80-character column | A (2.8) | 2.8 |
| 6.4 Light/dark, switches live | T: `ContrastTests`; A (2.8, 6.5); ✋ 7 live switch | 7.6 (owner) |
| 6.5 Select and copy as plain text | A (5.6) | 5.6 |
| 6.6 Find | A (5.1); in edit mode A (8.5) | 8.5 |
| 6.7 Zoom | T: `ZoomLevelsTests`; A (5.2); editor A (8.5) | 8.5 |
| 6.8 Print, Save as PDF | A (5.3) made a PDF; ✋ 8 the panel | 7.6 (owner) |
| 6.9 Reveal in Finder | A (5.4) | 5.4 |
| 6.10–6.12 Open in Editor, Change Editor, editor gone | A (5.5); ✋ 9 the picker | 7.6 (owner) |
| 6.13 State restoration | A (5.6) | 5.6 |
| 6.14 Keyboard and VoiceOver | A (5.7) keyboard; ✋ 10 VoiceOver | 7.6 (owner) |

## 7. Code highlighting

| AC | How | Last checked |
|---|---|---|
| 7.1–7.4, 7.6 | T: language, highlighting and `code.md` tests | 7.6 |
| 7.5 Contrast | T: `ContrastTests` | 7.6 |
| 7.7 2,000-line block | T (debug guard); A (6.6) release timing | 6.6 |

## 8. Performance

| AC | How | Last checked |
|---|---|---|
| 8.1–8.3 Cold, warm, large | S: `time-open.swift` | 8.7: 468 / 110 / 1,140 ms |
| 8.3 Smooth scrolling | ✋ 11 | 7.2 (owner) |
| 8.4 Bundle under 6 MB | S: add up the bundle's file sizes (below) | 8.7: 5,029,274 bytes |
| 8.5 Memory under 110 MB | footprint of each process after 12 s (7.2 method; quit MDView normally first, or restored windows count too) | 8.7: 104–106 MB |
| 8.6 Idle CPU | CPU time of every process over 30 s (7.2 method) | 8.7: 0.01 s |

Bundle size: `find build/mdview.app -type f -exec stat -f %z {} + | awk '{s+=$1} END {print s}'`

## 9. Offline, privacy and safety

| AC | How | Last checked |
|---|---|---|
| 9.1 No network | S: `check-offline.zsh`; T: `OfflineProtectionTests` | 8.7: pass |
| 9.2 Sandbox | `codesign -d --entitlements -` (user-selected read-write, ADR 0008); `sandbox_check` (7.3); writes only on Save A (8.3) | 8.7 |
| 9.3 No telemetry | Code and binary search (7.3) | 7.3 |
| 9.4 Only swift-markdown | `Package.resolved` (7.3) | 7.3 |
| 9.5–9.7 Folder bar, grant, Not Now | T: `FolderGrantListTests`; A (3.2); ✋ 3 a real grant | 7.6 (owner) |
| 9.8 No page without the block list | T; A (3.4) | 3.4 |

## 10. Errors and edge cases

| AC | How | Last checked |
|---|---|---|
| 10.1 Empty file | T: `edge/empty.md`; A (1.3) | 7.6 |
| 10.2 Not UTF-8 | T: `UTF8TextTests`, `edge/latin1.md`, `edge/utf16.md`; A (1.3) | 7.6 |
| 10.3 Can't be read | A (1.6): vanished Open Recent entry | 1.6 |
| 10.4 Any input, no crash or hang | T: fuzz, pathological and truncated tests | 7.6 |
| 10.5 Non-Markdown as plain text | T: `edge/plain.txt`; A (1.3) | 7.6 |

## 11. Edit mode (v1.1)

| AC | How | Last checked |
|---|---|---|
| 11.1 View → Edit Mode, ⌘/, check mark, Print dimmed | A (8.4) | 8.4 |
| 11.2 Opens in preview; open times unchanged | S: `time-open.swift` | 8.7: 468 / 110 ms |
| 11.3 Monospaced, wraps, no substitutions | A (8.4) typed text saved exactly; ✋ 12 light/dark | 8.4 |
| 11.4 Undo, Redo, Cut, Copy, Paste, Select All | A (8.4, 8.6) | 8.6 |
| 11.5 Preview after editing under 0.2 s | `previewRequested` → `documentVisible` signposts (8.7) | 8.7: 24–25 ms |
| 11.6 Edited marker; Save only on ⌘S, dimmed when clean | A (8.3, 8.4) | 8.4 |
| 11.7 Close / quit question | A (8.3) | 8.3 |
| 11.8 UTF-8, byte order mark, line endings | T: `UTF8TextEncodeTests` (every fixture round-trips); A (8.3) | 8.7: 271 tests |
| 11.9 Find in the source | A (8.5) | 8.5 |
| 11.10 Dimmed for bad bytes | T: `latin1.md`, `utf16.md` reported; A (8.4) | 8.4 |
| 11.11 Outside changes, own saves | A (8.6) | 8.6 |
| 11.12 Save errors: locked, read-only, gone | A (8.3) | 8.3 |
| 11.13 Keyboard and VoiceOver | A (8.5) focus and roles; ✋ 12 VoiceOver | 8.5 |
| 11.14 5 MB file in edit mode; size | A (8.7) switch, type, page with no hang; ✋ 12 scrolling | 8.7 |

## Hand checks

Use the release build: `open -a build/mdview.app <file>`.

1. **Default app (1.2).** Finder → Get Info on a `.md` → Open with →
   MDView → Change All. Double-click a `.md` file: it opens in MDView.
2. **Dock drop (1.5).** With MDView in the Dock, drag a `.md` file onto
   its icon: it opens.
3. **Folder grant (3.1, 3.2, 9.5–9.7).** Open `fixtures/images.md`.
   The bar appears; click **Allow…**, choose the `fixtures` folder:
   images appear without reopening. Quit, reopen: no bar. Open
   `fixtures/links.md` in a fresh state and click **Not Now**: the page
   stays, with placeholders.
4. **Links (4.1, 4.4–4.6).** In `fixtures/links.md`: a web link opens
   the browser and a mail link opens Mail; an image link opens Preview
   and a folder link opens Finder; hovering a link shows its
   destination; the missing-file link shows "File not found".
5. **Real editors (5.1–5.3).** Open a copy of `fixtures/typical.md` in
   MDView, scroll halfway, then edit and save it in TextEdit (plain
   text), VS Code and Xcode: MDView updates within half a second and
   stays where you were.
6. **Title and tabs (6.1, 6.2).** ⌘-click the window title: the path
   menu shows. Window menu: Merge All Windows and Show Tab Bar are
   there and work.
7. **Live dark mode (6.4).** With a file open, switch System Settings →
   Appearance between Light and Dark: the page, including code colours,
   follows at once.
8. **Print (6.8).** ⌘P shows the print panel with a preview of the page;
   PDF → Save as PDF writes a readable file.
9. **Editor picker (6.10–6.12).** File → Open in Editor… shows an app
   picker starting in Applications; choose TextEdit; the menu now reads
   "Open in TextEdit" and opens the file there. Change Editor… lets you
   pick another; choosing MDView itself is refused.
10. **VoiceOver (6.14).** ⌘F5, open `fixtures/elements.md`, VO-U: the
    rotor lists headings and links; images read their alt text; task
    items read as checkboxes.
11. **Smooth scrolling (8.3).** Run `time-open.swift` once (it makes
    `build/timing/large.md`), open that file and scroll quickly to the
    end: no stutter or spinning cursor.
12. **Edit mode (11.3, 11.13, 11.14).** Open a copy of
    `fixtures/typical.md`, press ⌘/: the source shows in a monospaced
    font and lines wrap. Switch Appearance between Light and Dark: the
    editor follows. With VoiceOver on, the editor reads as "Markdown
    source" and reads what you type. Open `build/timing/large.md`
    (made by `time-open.swift`), press ⌘/, scroll quickly to the end and
    type a few words: no stutter or spinning cursor. Close without
    saving (Don't Save).
