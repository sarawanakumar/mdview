# 0004. Small hand-written code highlighter

- **Status:** Accepted
- **Date:** 2026-11-04

## Context

Spec section 7 asks for coloured code blocks in nine languages, with no
highlighting library (vision non-goal). Page JavaScript is off (ADR 0003),
so highlighting can't happen in the page.

## Decision

Highlight in Swift, inside `MDViewCore`, while building the HTML:

- One shared scanner walks the code once, left to right, and recognises
  four token kinds: **keyword, string, comment, number**.
- Each language is a small table of rules: its keywords, comment markers
  (`//`, `/* */`, `#`, `<!-- -->`), string delimiters (including
  triple-quoted and template strings) and number format.
- Language tags and their aliases map to a rule table (spec 7.1).
- Tokens are wrapped in `<span class="tok-keyword">` and so on; colours
  live in `preview.css`, with light and dark values that meet 4.5:1
  contrast (spec 7.5).
- An unclosed string or comment simply runs to the end of the block; the
  scanner always moves forward, so it can't hang (spec 7.6).

## Alternatives considered

- **A highlighting library** (in Swift or JavaScript). Rejected: against
  the no-dependencies rule, and JavaScript is off.
- **Regular expressions per language.** Quick to write, but multi-line
  strings and comments are hard to get right, and badly written patterns
  can be very slow. Rejected.
- **Full grammars (like editors use).** Accurate but large. Rejected: the
  goal is "clearly readable", not editor-grade.

## Consequences

- Small, fast and easy to extend: a new language is one rule table.
- Not as accurate as an editor: no colouring of types, function names or
  string interpolation contents. Acceptable per the vision.
- Each language gets its own unit tests, including malformed input.
