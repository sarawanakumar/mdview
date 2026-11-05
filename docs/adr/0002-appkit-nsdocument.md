# 0002. AppKit app built on NSDocument

- **Status:** Accepted; read-only document changed by
  [ADR 0008](0008-edit-mode.md) (edit mode, saved on ⌘S)
- **Date:** 2026-11-04

## Context

Spec sections 1 and 6 ask for a lot of standard Mac document behaviour:
open from Finder and the Dock, Open Recent, one window per file, bring an
already-open file to the front, window tabs, title bar path menu, and
restoring windows on relaunch. We also need custom menu items (Open in
Editor, Change Editor, Reveal in Finder, zoom) and a fast launch.

## Decision

Build the app with **AppKit** and an `NSDocument` subclass for each open
file, managed by `NSDocumentController`. The document is read-only: no
saving, no autosave. Menus and windows are set up in code, with no
storyboards or XIBs.

## Alternatives considered

- **SwiftUI `DocumentGroup(viewing:)`.** Less code for the basic window, but
  less control over menus, window behaviour and the web view, and the
  preview would be wrapped in AppKit anyway. Rejected: it would add a layer
  without removing the AppKit work.
- **Plain AppKit windows without `NSDocument`.** Full control, but we'd
  rebuild Open Recent, de-duplication and state restoration by hand.
  Rejected: more code for the same result.

## Consequences

- Most of spec sections 1 and 6 comes from the system with little code.
- AppKit is mature and starts quickly.
- Menus written in code are a little verbose but are easy to read and
  review, unlike XIB files.
