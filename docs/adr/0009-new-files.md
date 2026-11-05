# 0009. New files, saved once through a save panel, as .md only

- **Status:** Accepted (by the owner, 2026-11-05)
- **Date:** 2026-11-05
- **Changes:** [ADR 0008](0008-edit-mode.md) points 5 and 8 ("no new files",
  "no save panel"), and the vision's "No rich editing" non-goal, which
  lists new files.

## Context

Edit mode (ADR 0008) lets the owner fix open files without leaving
MDView. The owner now wants to start a new note there too: create a file
and save it, "only save as .md, nothing else". It goes in v1.1, which is
committed but not yet tagged.

What v1.1 does today, and what's in the way:

- `MarkdownDocument.prepareSavePanel` always returns false, so no save
  panel can ever open (ADR 0008: no Save As). A new file needs one, once.
- `save(_:)` refuses when the document has no file, which is what an
  untitled document is.
- Info.plist gives the Markdown type the Viewer role, so
  `NSDocumentController` has no default type for File → New.
- `MarkdownDocument` starts the file watcher when its window opens. An
  untitled document has nothing to watch until it's saved.
- The sandbox already grants `files.user-selected.read-write` (ADR 0008),
  which covers writing to a place the user picks in the save panel.
- The app has under 1 MB left under spec 8.4's 6 MB.

## Decision

Chosen by the owner in an interview on 2026-11-05:

1. **File → New (⌘N)** opens an untitled window ("Untitled",
   "Untitled 2", …), **in edit mode** with the cursor in the empty editor.
   Launching MDView with no file still shows the Open panel (spec 1.8);
   nothing makes untitled windows by itself.
2. **The first ⌘S asks where.** For an untitled window, File → Save
   shows the standard save panel, once. After that the window is a normal
   document and ⌘S saves in place, as in ADR 0008.
3. **Only `.md`.** The save panel allows exactly one type, Markdown with
   the `.md` extension (`allowedContentTypes`, `allowsOtherFileTypes`
   false), with no file format menu. The saved file always ends in `.md`.
4. **Replace is standard.** Choosing a name that exists gets macOS's own
   "already exists. Do you want to replace it?", and is replaced only if
   the user confirms.
5. **No Save As for opened files.** The save panel only ever appears for
   an untitled window. `prepareSavePanel` returns false for every
   document that has a file, so ADR 0008's rule still holds for them,
   including a file that's been deleted (spec 11.12).
6. **Saved like every other file.** UTF-8, no byte order mark, line
   endings as typed (`UTF8Text.encode`).
7. **After the first save** the window shows the file's name and path
   menu, it's added to Open Recent, the file watcher starts (spec section
   5), and the preview renders again against the file's folder, so local
   images and links work (with the folder bar of spec 9.5 if needed).
8. **No autosave, still.** An untitled window with text asks Save /
   Don't Save / Cancel on close and quit; one with nothing typed closes
   without asking. Untitled windows aren't restored after a relaunch
   (their text lives only in the window until it's saved).
9. **Implementation, briefly:** `MarkdownDocumentController.defaultType`
   returns the Markdown type (Info.plist keeps the Viewer role, as in
   ADR 0008); `save(_:)` lets untitled documents through to NSDocument;
   `prepareSavePanel` sets up the `.md`-only panel for untitled documents
   only; the watcher starts once the document has a file.

## Alternatives considered

- **Save As for every window.** Also asked; the owner chose new files
  only. It would mean a panel for opened files too, against ADR 0008's
  "no Save As", and more cases to test (saving a copy, which file the
  window then shows).
- **Open new windows in preview,** like other windows. Rejected: an
  empty preview is useless; a new file is for typing.
- **Never replace an existing file** from the panel. Safer, but needs
  our own check on top of the standard panel, and macOS already asks.
  Rejected.
- **Choose the name and folder first** (a panel before the window
  opens). Rejected: slower to start a note, and not how Mac apps work.
- **Allow `.markdown` or other extensions.** The owner asked for `.md`
  only.
- **Ship in v1.2.** Also asked; the owner chose to fold it into v1.1, so
  roadmap 8.7's measurements are done again at the end.

## Consequences

- MDView can now create files, but only where the user chooses in a save
  panel, only as `.md`, and only from a window they made with File → New.
- On acceptance:
  - vision.md: the "No rich editing" non-goal no longer lists new files.
  - CLAUDE.md: the "Writes only on save" rule also covers a new file's
    first save through the save panel.
  - ADR 0008's status gains "points 5 and 8 changed by 0009".
- The spec gains section 12 (new files); 11.6, 11.12 and the out-of-scope
  list change to match (same session as this ADR).
- Roadmap: new tasks 8.8–8.10, and v1.1's measuring and release step
  moves to 8.11.
- Open times aren't affected: nothing new happens when a file is opened.
