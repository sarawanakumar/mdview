# Vision

## Why

Offline Markdown viewers for macOS tend to cost money and come loaded with
features I never use: editors, sync, export pipelines, plugin systems. I just
want to *read* a Markdown file, instantly, without opening an IDE or a browser.

mdview (shown to users as **MDView**) is an ultra-lightweight, incredibly
simple Markdown viewer for macOS.
It does one thing: open a `.md` file and show a clean, readable preview, fast.

## For whom

Primarily me: someone who has lots of Markdown files (notes, READMEs, docs) on
a Mac and wants to read them in a native app. It is open source, so anyone who
wants the same thing is welcome to use it, but my own daily use drives every
decision.

## What it is

- A native macOS desktop app for macOS 15 Sequoia and later, built with Apple's SDKs and system APIs. The
  only package it uses is Apple's own `swift-markdown` (see Non-goals).
- A **viewer** first. Since v1.1 it has a plain edit mode for small fixes
  (ADR 0008), but it's not an editor app.
- Fully offline: it never touches the network.

## What success looks like

The core experience: **I double-click a `.md` file in Finder (or press Cmd+O
in the app), and the rendered preview appears almost immediately.**

Concretely, v1 is successful when:

| Measure | Target |
|---|---|
| Double-click a typical file (< 100 KB) in Finder, app not running → preview visible | under 0.5 s |
| Same, app already running | feels instant (under 0.2 s) |
| App bundle size | under 5 MB (6 MB since v1.1, spec 8.4) |
| Third-party dependencies | zero (Apple's `swift-markdown` is the one allowed package) |
| Network requests | zero, ever |
| Daily use | I've set it as my default app for `.md` and don't miss anything |

## Must-haves for v1

1. **Opens `.md` files from Finder and Cmd+O.** Registers as a viewer for
   `.md` / `.markdown` so it can be the default app.
2. **Renders common Markdown well:** headings, paragraphs, emphasis, lists,
   links, blockquotes, inline code, fenced code blocks, horizontal rules,
   plus the GitHub-flavored basics people actually use: tables, task lists,
   strikethrough.
3. **Shows local images** referenced with relative paths.
4. **Reloads automatically** when the file changes on disk, so it works
   alongside whatever editor I write in.
5. **Looks native:** system fonts, follows light/dark mode, standard
   windows (one window per file, native tabs come free with macOS).
6. **Highlights code in fenced code blocks** for a small set of common
   languages (for example Swift, Python, JavaScript/TypeScript, shell, JSON,
   YAML, HTML/CSS). Code in other languages shows as plain monospaced text.
   Colours follow light/dark mode.

## Non-goals

- **No third-party dependencies.** No libraries, frameworks or packages
  from anyone other than Apple. The single exception is Apple's own
  [`swift-markdown`](https://github.com/swiftlang/swift-markdown) package
  (and the Apple-maintained `swift-cmark` it builds on), added through Swift
  Package Manager. It parses full GitHub-flavored Markdown, which the
  built-in system APIs can't, and Apple maintains it.
- **No rich editing.** v1.1 adds a plain-text edit mode, swapped in place
  of the preview and saved only on ⌘S (ADR 0008), and File → New for a
  new `.md` file (ADR 0009). No side-by-side view, colouring, autosave or
  Save As: for real writing, opening the file in my editor is one click
  away.
- **No network:** no remote images, no update checks, no telemetry, no sync.
- **No export** (PDF, HTML) in v1. Print from the system menu is acceptable
  if it comes free.
- **No plugins, custom themes or settings screens.** Sensible defaults only.
- **No Mermaid diagrams or math** in v1. They can be revisited later only if
  they can be done natively without hurting speed or size.
- **No highlighting library.** Code highlighting is done in-project, without
  a third-party highlighter. It aims for "clearly readable", not
  editor-grade accuracy, and must not noticeably slow down opening a file.

## Guiding principles

- **Speed over features.** If a feature slows down open-to-preview, it doesn't
  ship.
- **Simple over clever.** The codebase should stay small enough to read in
  one sitting.
- **Native over custom.** Use the system's controls, fonts and behaviors
  rather than reinventing them.

## Open questions

- **Code highlighting approach.** A small hand-written tokenizer per
  language (keywords, strings, comments, numbers) is the likely answer. The
  exact language list and how far to take it go to an ADR.
- **Rendering approach.** Native text views versus the system's built-in
  `WKWebView` with local HTML. Both are Apple SDKs; the choice trades
  fidelity against launch speed and memory. Also an ADR.
- **Distribution.** Decided in ADR 0007: build from source for v1. A
  notarised release can come later if others want one.
