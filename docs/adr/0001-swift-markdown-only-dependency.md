# 0001. Apple's swift-markdown is the only package dependency

- **Status:** Accepted
- **Date:** 2026-11-04

## Context

The vision rules out third-party dependencies. macOS's built-in Markdown
support (`AttributedString(markdown:)`) only handles inline formatting
(emphasis, links, inline code). It can't give us tables, lists, block
quotes or code blocks as structure, so it can't meet spec section 2.

## Decision

Use Apple's [`swift-markdown`](https://github.com/swiftlang/swift-markdown)
package, added through Swift Package Manager and pinned to an exact version.
It brings in `swift-cmark`, Apple's maintained fork of the GitHub-flavored
CommonMark parser. These two are the only packages allowed. Anything else
needs a new ADR.

## Alternatives considered

- **Write our own parser.** No dependency at all, but correct CommonMark
  parsing is a large, fiddly job, and it would be most of the codebase.
  Rejected: against "simple over clever".
- **`AttributedString(markdown:)` only.** Built in, but can't do block
  elements. Rejected: fails the spec.
- **Other open-source parsers** (for example `cmark-gfm` directly, or
  community Swift parsers). Rejected: not Apple's, so against the rule.

## Consequences

- Full GitHub-flavored parsing (tables, task lists, strikethrough) without
  writing a parser.
- Pinned to **0.9.0** (with `swift-cmark` 0.9.0). Its build-time docs
  plugin is not pulled in when used from Xcode, so these are the only two
  packages resolved.
- Adds about 1 MB per chip type (2.2 MB for a stripped universal app);
  full size check in roadmap 0.5.
- We depend on Apple keeping it maintained; pinning the version means
  updates are deliberate.
- Checked in roadmap 0.2: tables (with alignment), task lists,
  strikethrough, nested lists, list start numbers and nested quotes all
  parse correctly. Not supported: footnotes, GitHub-style bare-URL links,
  and front matter (parsed as a rule plus a heading, so it must be stripped
  first). By default it also turns straight quotes, `--` and `...` into
  typographic ones.
