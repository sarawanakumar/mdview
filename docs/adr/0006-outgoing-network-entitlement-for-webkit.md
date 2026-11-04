# 0006. Allow the outgoing-network entitlement so WebKit can run

- **Status:** Accepted
- **Date:** 2026-11-04
- **Changes:** ADR 0005, point 1 ("no network entitlement")

## Context

ADR 0003 renders with `WKWebView`. ADR 0005 runs the app in the App
Sandbox with no network entitlement, so macOS would enforce that mdview
stays offline.

Roadmap 0.3 showed these can't both hold. On macOS 26.6, in a sandboxed
app without `com.apple.security.network.client`, WebKit's web content and
GPU helper processes fail to launch and nothing renders. Re-signing the
same build showed it works with that entitlement, or without the sandbox,
and that the hardened runtime makes no difference.

## Decision

Keep the web view (ADR 0003) and the sandbox (ADR 0005), and add the
**outgoing-network entitlement** (`com.apple.security.network.client`).
Incoming connections stay off.

Offline is then enforced by mdview and WebKit rather than by macOS, in
layers:

1. The HTML renderer never emits remote URLs (remote images become
   placeholders, spec 3.5).
2. A `WKContentRuleList` blocks every load except `mdview-file:`. If the
   rule list fails to compile or install, the document is **not shown**
   (an error appears instead), so there's never an unprotected page.
3. Page JavaScript is off, so a file can't create requests.
4. Clicked web links are cancelled in the web view and handed to the
   default browser (`NSWorkspace`).
5. mdview has no networking code of its own (no `URLSession` or similar).

## Alternatives considered

- **Switch to a native text view** (ADR 0003's fallback). Keeps macOS
  enforcing "no network", but needs a lot of custom layout code for
  tables, sideways-scrolling code blocks and quote bars. Rejected by the
  owner: the web view's simplicity is worth more.
- **Drop the sandbox.** Also works, but loses the file-access limits too.
  Rejected: no advantage over this option.

## Consequences

- The App Sandbox no longer guarantees offline; the five layers above do.
  Spike results: with the rule list, a remote image is blocked; without
  it, the same image loads. So layer 2 is real and must stay.
- The sandbox still limits file access (ADR 0005 points 2 and 3 stand).
- Spec 9.1 is reworded to match. The network monitor check before
  release (roadmap 7.3) is now the main proof of "zero network requests".
- An automated test should load a page with remote images and check
  nothing remote arrives, so a regression in the rule list is caught.
- Only tested on macOS 26.6. macOS 15 might not need the entitlement, but
  one build has to work on both, so it stays.
