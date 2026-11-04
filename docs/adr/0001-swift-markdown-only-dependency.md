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
- Adds roughly 1–2 MB to the app; to be confirmed against the 5 MB limit.
- We depend on Apple keeping it maintained; pinning the version means
  updates are deliberate.
- Footnotes may not be supported; to check in the first spike.
