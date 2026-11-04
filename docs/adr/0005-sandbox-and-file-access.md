# 0005. App Sandbox, custom URL scheme and folder access grants

- **Status:** Accepted; point 1 changed by
  [ADR 0006](0006-outgoing-network-entitlement-for-webkit.md)
- **Date:** 2026-11-04

## Context

Spec 9.1 and 9.2 want the app sandboxed with no network permission, so
macOS itself guarantees it stays offline. But a sandboxed app can only read
the file the user opened. It can't read `img/a.png` or `other.md` next to
it, which spec 3.1 and 4.2 need. The web view also needs a safe way to load
local images.

## Decision

1. **Sandbox on, no network entitlement.** Only "read files the user
   selected" is granted. *Changed by ADR 0006: WebKit can't run in the
   sandbox without the outgoing-network entitlement, so that is granted
   too, and offline is enforced by mdview and WebKit instead.*
2. **Custom URL scheme `mdview-file://`.** The page's base URL points at
   the document's folder through this scheme. Every image request goes to
   our `AssetSchemeHandler`, which reads the file in the app and hands back
   the bytes. The web view never reads the disk itself, and nothing else
   can be loaded.
3. **One-time folder access.** When a document refers to local images or
   files the app can't read, the window shows a slim bar: *"Allow mdview to
   show images and linked files in this folder."* Clicking it opens the
   standard folder picker, pointed at the document's folder. The user can
   pick that folder or any folder above it (for example their home folder,
   to never be asked again). The grant is saved as a security-scoped
   bookmark and reused on every launch.

## Alternatives considered

- **No sandbox.** Everything just works, no prompts. But "no network" would
  rest only on our own code, not on macOS. Rejected for now: the offline
  guarantee is part of the vision. Worth revisiting if the prompt proves
  annoying.
- **Ask on every document.** Safer, but tiring. Rejected.
- **Load files with `loadFileURL(allowingReadAccessTo:)`.** Lets WebKit
  read a folder directly, but gives less control over what's loaded and
  still needs the sandbox grant. Rejected in favour of the scheme handler.

## Consequences

- macOS enforces that the app never touches the network.
- Documents without local images or links never show the bar.
- The spec now reflects this: 9.2 covers granted folders, 9.5–9.7 describe
  the folder access bar, and 3.1, 3.2 and 4.2 note that they need a grant.
- Must check in the first spike that `WKWebView` works in the sandbox
  without the network entitlement.
