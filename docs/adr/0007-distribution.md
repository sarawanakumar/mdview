# 0007. Distribute v1 as build-from-source

- **Status:** Accepted
- **Date:** 2026-11-05

## Context

Roadmap 7.5 asks how people get mdview. The vision lists three options:
build from source, a signed GitHub release, or a Homebrew cask. mdview is
built mainly for its owner's own daily use, and it's open source so others
can use it too.

What macOS does with each (checked in roadmap 7.5, macOS 26.6):

- **A copy you build yourself** is ad-hoc signed with the hardened runtime
  and has no download quarantine. It opens normally, registers for
  `.md` files and can be the default app. A fresh clone builds a
  universal (Intel and Apple silicon) release in about 30 s with Xcode.
  The build fetches swift-markdown and swift-cmark from their own
  repositories, pinned exactly (ADR 0001).
- **A downloaded app** gets the quarantine flag. Unless it's signed with
  a Developer ID and notarised by Apple, Gatekeeper refuses to open it
  (`spctl` rejects the ad-hoc build). Since macOS 15, users can only get
  past that in System Settings → Privacy & Security → Open Anyway,
  separately for each app.
- A Developer ID needs a paid Apple Developer Program membership. Each
  release then needs signing, `notarytool` and stapling, using Apple's
  own tools.
- Shipping a built app also means shipping the packages' license texts:
  Apache 2.0 with its NOTICE for swift-markdown, and BSD 2-Clause and the
  other notices in its COPYING for swift-cmark. Building from source
  doesn't redistribute either package; Swift Package Manager fetches them.

## Decision

For v1, **build from source only.** The README (roadmap 7.8) gets short
install steps:
1. Clone the repository.
2. Build a release with `xcodebuild`.
3. Copy `mdview.app` to `/Applications`.
4. Set it as the default app for `.md` in Finder's Get Info.

To update: pull and build again.

No binary is published, so there's no signing, notarisation or release
pipeline to keep up, and the app stays exactly what's in the repo.

## Alternatives considered

- **Notarised app on GitHub Releases.** The friendliest for people who
  don't use Xcode: download, unzip, open. But it needs a paid developer
  membership, and every release needs signing, notarisation, a zip and
  the license texts added to the bundle (a few KB; the app has about
  64 KB left under spec 8.4's 5 MB). Worth doing later if others ask for
  it. This ADR would then be replaced.
- **Un-notarised zip on GitHub.** Free, but every user hits Gatekeeper's
  refusal and has to find Open Anyway in System Settings. It also trains
  people to bypass a security check. Rejected.
- **Homebrew cask.** Needs a downloadable release first (the option
  above), plus a cask to maintain. Later, if ever.

## Consequences

- Installing needs Xcode 16 or later (spec: macOS 15+), so mdview is for
  people comfortable with a terminal. That fits a personal tool.
- No code signing settings change: the project keeps ad-hoc signing
  (`CODE_SIGN_IDENTITY = "-"`), with the sandbox and hardened runtime on.
- Roadmap 7.8 becomes: tag v1.0, add a license, and write the README's
  install steps. "Publish" means pushing the tagged repository.
- The About box's credits (roadmap 7.4) already name both packages and
  their licenses. Full license texts are only needed if a binary is ever
  published.
