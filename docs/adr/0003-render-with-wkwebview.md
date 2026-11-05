# 0003. Render as HTML in WKWebView, with JavaScript off

- **Status:** Accepted
- **Date:** 2026-11-04

## Context

The parsed Markdown has to be drawn on screen. Spec section 2 needs
tables, code blocks that scroll sideways on their own, quote bars and block
backgrounds. Section 6 needs selection, find, zoom, print and VoiceOver.
Section 8 needs it fast and light. Both candidates below are Apple SDKs.

## Decision

Turn the Markdown into an HTML page in Swift and show it in a `WKWebView`.
Lock the web view down:

- page JavaScript off (`allowsContentJavaScript = false`)
- a content rule list that blocks every remote load
- a non-persistent data store
- local files served only through our own URL scheme (ADR 0005)

Start the web view early at launch to hide WebKit's start-up cost.

## Alternatives considered

- **Native text view (`NSTextView` with attributed text).** Fastest to
  appear and lightest on memory, and selection, find bar and printing come
  free. But tables need `NSTextTable` (only in the older text system),
  sideways-scrolling code blocks and tables need embedded views inside the
  text, and quote bars and block backgrounds need custom drawing. That's
  a lot of tricky layout code. Rejected: works against "simple over clever".
- **SwiftUI views per block.** Tables and scrolling code blocks are easy,
  but you can't select text across blocks, and find and print would have
  to be built by hand. Rejected: fails spec 6.5, 6.6 and 6.8.

## Consequences

- Layout of every spec 2 element is a few lines of CSS. Light/dark,
  zoom, printing, selection and VoiceOver come from WebKit.
- Start-up cost: WebKit runs helper processes. Cold open under 0.5 s must be
  proven in the first spike; if it fails, this ADR is revisited, with the
  native text view as the fallback.
- Memory is higher than a text view (WebKit's helper processes); the
  100 MB limit in spec 8.5 must be checked. *(2026-11-05: the limit is
  now 110 MB; see spec 8.5 and progress.md, roadmap 7.2.)*
- *Spike results (roadmap 0.4, 0.6), 50 KB file, macOS 26.6: cold open
  median 359 ms, warm 172 ms; memory 86 MB across the app and its three
  WebKit processes. Both within target, memory with only ~14 MB to
  spare.*
- WebKit doesn't provide AppKit's standard find bar, so we build a slim one
  on top of `WKWebView.find`.
- The app can still run its own small scripts in the page (for keeping the
  scroll position on reload), even with page JavaScript off.
