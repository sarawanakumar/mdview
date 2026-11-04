# mdview

An ultra-lightweight, read-only Markdown viewer for macOS 15 and later.
Native AppKit, fully offline. Early development: see
[docs/roadmap.md](docs/roadmap.md) for where things stand.

## Layout

```
mdview.xcodeproj   the Xcode project (app target "mdview")
App/               the macOS app (AppKit, WebKit)
Packages/
  MDViewCore/      Markdown → HTML logic, no AppKit; tested with `swift test`
fixtures/          Markdown test files (spec.md, "Test files")
spike/             throwaway M0 prototype, removed after M1
docs/
  vision.md        why, for whom, what success looks like
  spec.md          what the product does, with acceptance criteria
  architecture.md  how it is built
  adr/             one file per architecture decision
  roadmap.md       milestones and ordered tasks
  progress.md      running log, updated at the end of each session
CLAUDE.md          standing instructions Claude reads every session
.claude/
  settings.json    permissions and hooks (committed, shared)
  commands/        reusable prompts as slash commands
  agents/          specialised subagents (reviewer, tester, ...)
```

## Building

Needs Xcode 16 or later.

```bash
xcodebuild -project mdview.xcodeproj -scheme mdview build
```

```bash
swift test --package-path Packages/MDViewCore
```

## Workflow

Docs come first, in this order: vision → spec → architecture (+ ADRs) → roadmap.
Code starts only after the roadmap exists.
