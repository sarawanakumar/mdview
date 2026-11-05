# mdview

An ultra-lightweight Markdown viewer for macOS 15+. Native
AppKit, fully offline, open source, built primarily for its owner's daily
use. Since v1.1 it has a plain edit mode (ADR 0008). Speed and simplicity beat features.

## Start of every session

1. Read `docs/progress.md` (latest entry first) to see where things stand.
2. Find the next unticked task in `docs/roadmap.md`, unless told otherwise.
3. Read the spec criteria (`docs/spec.md`) and ADRs that task names before
   changing anything.

Other docs: `docs/vision.md` (why), `docs/architecture.md` (how),
`docs/adr/` (decisions), `docs/checklist.md` (every spec criterion and how
it's checked, run before a release).

## End of every session

Add an entry at the top of `docs/progress.md`: date, what was done, what's
open, what's next. Tick finished roadmap tasks (`[x]`) only when their spec
criteria pass. Record measurements (timings, app size) with the numbers.

## Hard rules

- **No dependencies** except Apple's `swift-markdown` and its
  `swift-cmark`, pinned to an exact version (ADR 0001). No other packages,
  frameworks, build tools, scripts from the internet, or vendored code.
- **No network.** No code that makes network requests (no `URLSession`
  or similar). The app has the outgoing-network entitlement only because
  WebKit needs it (ADR 0006), so the web view's block list is what keeps
  mdview offline: never weaken it, and never show a page if it failed to
  load. No incoming-network entitlement.
- **No page JavaScript.** Only the app's own small scripts may run in the
  web view.
- **Writes only on save.** mdview writes a user's file only when they
  press ⌘S in edit mode (ADR 0008), and creates a file only when they
  save a new window through the `.md`-only save panel (ADR 0009): no
  autosave, no other writes.
- **Stay in scope.** Work on the current roadmap task. Anything listed as a
  non-goal in `vision.md` or "out of scope" in `spec.md` needs the owner's
  OK first.
- **Decisions go in ADRs.** A significant or hard-to-reverse choice
  (new API approach, changing an accepted ADR, any dependency question)
  gets a new ADR in `docs/adr/`, numbered next in sequence, status
  Proposed until the owner accepts it. Don't silently go against an
  accepted ADR.
- **Keep docs in step.** If behaviour changes, update `spec.md`; if
  structure changes, update `architecture.md`.

## Code

- Swift 6 with strict concurrency checking. AppKit and WebKit only; no
  SwiftUI, storyboards or XIBs (ADR 0002).
- `Packages/MDViewCore` holds all Markdown, HTML and highlighting logic and
  must not import AppKit or WebKit. The app target handles windows, files
  and the web view.
- Prefer the smallest clear solution. Don't add abstractions, options or
  settings that a current spec criterion doesn't need.
- No force unwraps or `try!` outside tests. Bad input must never crash or
  hang the app (spec 10.4).
- Parsing, rendering and file reads stay off the main thread.
- Don't let anything add noticeable time to opening a file. When touching
  the open path, measure before and after (spec section 8).

## Testing

- `MDViewCore` changes need unit tests; renderer output is checked against
  expected HTML for the files in `fixtures/` (stored in
  `fixtures/expected/`). After a deliberate rendering change, re-record
  with `MDVIEW_RECORD_EXPECTED=1 swift test --package-path
  Packages/MDViewCore` and review the diff before committing.
- Core tests: `swift test --package-path Packages/MDViewCore`
- App build: `xcodebuild -project mdview.xcodeproj -scheme mdview build`
  (add `-configuration Release -destination 'generic/platform=macOS'`
  for a universal release build).
- Launch builds with `open path/to/mdview.app`, not the binary directly.
- To test Finder / Open With behaviour, copy the build to the git-ignored
  `build/` folder and register it with `lsregister -f build/mdview.app`.
  macOS doesn't offer apps from temporary folders in Open With.
- The Xcode project uses folder-synced groups: new files in `App/` are
  picked up automatically. Files that must not be copied into the app
  (entitlements, Info.plist) are listed as exceptions in the project.
- Before saying something works, run the tests or the app and say what you
  checked. If something couldn't be checked, say so.
- Open timing (spec section 8): copy a release build to `build/mdview.app`,
  then run `swift scripts/time-open.swift` from the repository root.
- Offline check (spec 9.1): `zsh scripts/check-offline.zsh` opens every
  fixture while `nettop` watches, and fails if any mdview process had a
  socket.
- Colour changes in `preview.css` are checked by `ContrastTests` (every
  text colour at least 4.5:1, light and dark).

## Git

- Commit only when the owner asks. Small commits, one task each, message
  naming the roadmap task (for example "1.3: read-only MarkdownDocument").
- Never commit build products, `DerivedData` or personal Xcode settings.

## Writing docs

Plain, short sentences. Explain the why. Link spec criteria by number
(for example "spec 5.3") and ADRs by number.
