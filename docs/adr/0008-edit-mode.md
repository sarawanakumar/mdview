# 0008. A plain-text edit mode, saved only on ⌘S

- **Status:** Accepted (by the owner, 2026-11-05)
- **Date:** 2026-11-05
- **Changes:** the vision's "No editing" non-goal, CLAUDE.md's "Read-only"
  rule, the read-only part of [ADR 0002](0002-appkit-nsdocument.md), and
  the read-only entitlement in [ADR 0005](0005-sandbox-and-file-access.md)
  point 1.

## Context

After a week of daily use (roadmap 7.7) the owner wants to fix small
things (a typo, a checkbox, a line) without leaving MDView. "Open in
Editor" (spec 6.10) works, but switching apps for a one-word change is
slow. The owner asked for "a toggle, as simple and easy as possible" that
switches a window from preview to editing, for v1.1.

v1 was built as a viewer on purpose, and several decisions rest on that:

- The vision lists "No editing" as a non-goal.
- CLAUDE.md's hard rules say mdview never writes to the user's files.
- `MarkdownDocument` is a read-only `NSDocument` (ADR 0002): no saving,
  no autosave, no edited state.
- The sandbox grants `files.user-selected.read-only` (ADR 0005).
- Bad bytes are replaced on reading (spec 10.2), and a leading byte order
  mark is dropped (`UTF8Text`), so the text in memory isn't always the
  file's exact bytes.

The app has about 64 KB left under the 5 MB size limit (spec 8.4), and
open times must not get slower (spec 8.1, 8.2).

## Decision

Add an **edit mode** to each window, chosen by the owner in an interview
on 2026-11-05:

1. **One toggle, in place.** **View → Edit Mode** (⌘/) swaps the preview
   for a plain-text editor of the file's full source, in the same window.
   Choosing it again swaps back. There is no split view and no toolbar
   button. (⌘E is already Use Selection for Find, ⇧⌘E Open in Editor.)
2. **Plain `NSTextView`.** System monospaced font, light and dark, undo,
   standard find bar. No colouring and no automatic substitutions (quotes,
   dashes, links, spelling corrections), so what's typed is what's saved
   (in the spirit of spec 2.15). It's part of AppKit, so it adds no size
   beyond our own code.
3. **Created on demand.** Every window opens in preview, including
   restored ones. The editor is made the first time a window switches to
   it, so opening a file does exactly what it does in v1.
4. **Preview shows the unsaved text.** Switching back renders what's in
   the editor, saved or not, through the normal render path.
5. **Saved only on ⌘S.** `MarkdownDocument` becomes an editable
   `NSDocument` with `autosavesInPlace` still false: the title bar shows
   the standard edited marker, File → Save writes the file, and closing
   or quitting with unsaved edits asks Save / Don't Save / Cancel. No
   autosave, no Versions, no Save As, so MDView never writes a file
   unless the user saves.
6. **Write back faithfully.** Saving writes UTF-8, puts back a byte order
   mark if the file had one, and doesn't touch line endings. Files that
   didn't decode cleanly (invalid UTF-8, UTF-16: the spec 10.2 notice)
   can't be edited: the menu item is dimmed, so replacement characters
   are never written over the original bytes.
7. **Outside changes.** With no unsaved edits, a change on disk reloads
   as today (spec section 5), in either mode. With unsaved edits, an
   alert asks: **Keep My Edits** or **Reload from Disk**. MDView's own
   saves are recognised (the bytes on disk match what was just written)
   and never cause a reload or an alert.
8. **Sandbox: read-write for chosen files.** The entitlement changes from
   `files.user-selected.read-only` to `files.user-selected.read-write`.
   Folder grants (ADR 0005 point 3) stay as they are; whether a file
   opened through a grant made under the old read-only entitlement can be
   saved is checked in roadmap 8.1. If it can't, saving shows the
   standard error and the folder bar offers to grant the folder again.

## Alternatives considered

- **Keep "Open in Editor" only.** No new code or risk, but it's what the
  owner finds too slow for small changes. Rejected.
- **Side-by-side source and preview.** The common layout in Markdown
  editors, but it needs wide windows, re-renders on every keystroke and
  is more code. Rejected for the simpler swap.
- **macOS autosave in place, with Versions.** No prompts and the standard
  modern behaviour, but MDView would write the file on its own while the
  user types, and it adds Versions and Revert menus. Rejected: a viewer
  that writes without being asked is surprising.
- **Markdown colouring in the editor.** Nicer to read, but it's more code,
  more tests and has to stay smooth on 5 MB files (spec 8.3), with little
  size to spare. Rejected for now; it can come later as its own ADR.
- **Allow editing files with bad bytes, with a warning.** More flexible,
  but one click on Save destroys the original bytes. Rejected.

## Consequences

- MDView can now change the user's files, but only when they press ⌘S
  in a window they switched to edit mode. Everything else stays read-only.
- On acceptance:
  - vision.md: "A viewer, not an editor" and the "No editing" non-goal
    become "a viewer first, with a plain edit mode; no rich editing".
  - CLAUDE.md: the "Read-only" hard rule becomes "writes only on an
    explicit save in edit mode (ADR 0008)".
  - ADR 0002's status gains "read-only part changed by 0008"; ADR 0005's
    gains "entitlement changed to read-write by 0008".
- The spec gains section 11 (edit mode), and 6.6, 6.7, 9.2 and the
  out-of-scope list change to match (done in the same session as this
  ADR, marked as v1.1).
- `MDViewCore` gains the encoding side of `UTF8Text` (text back to bytes,
  with the byte order mark), with unit tests.
- The Edit menu gains Undo, Redo, Cut and Paste; File gains Save.
- New risks to check in roadmap 8.1: `NSDocument`'s safe save (write a
  temporary file, then replace) inside the sandbox, and that the file
  watcher (spec 5.3) keeps watching after our own save replaces the file.
- The release becomes v1.1.0, still build-from-source (ADR 0007).
