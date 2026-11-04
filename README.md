# mdview

A Markdown viewer. This project is in early planning: there is no application code yet.

## Layout

```
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

## Workflow

Docs come first, in this order: vision → spec → architecture (+ ADRs) → roadmap.
Code starts only after the roadmap exists.
