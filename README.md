# mdview

**MDView** is an ultra-lightweight, read-only Markdown viewer for macOS 15
and later. Double-click a `.md` file and the rendered page appears in
under half a second. Native AppKit, fully offline, no settings.

(The app is shown as "MDView"; the project, code and bundle ID use
`mdview`.)

- GitHub-flavored Markdown: tables, task lists, strikethrough, front
  matter hidden, bare web addresses linked
- Code blocks coloured for Swift, Python, JavaScript/TypeScript, shell,
  JSON, YAML, HTML and CSS, in light and dark mode
- Local images, once you allow the folder; remote images are never
  downloaded
- Reloads by itself when the file is saved, keeping your place
- Find, zoom, print, Reveal in Finder, Open in Editor
- Sandboxed, and never touches the network. Its only package is Apple's
  `swift-markdown`.

## Install

MDView is installed by building it from source
([ADR 0007](docs/adr/0007-distribution.md)). You need a Mac with macOS 15
or later and Xcode 16 or later.

```bash
git clone https://github.com/sarawanakumar/mdview.git
cd mdview
xcodebuild -project mdview.xcodeproj -scheme mdview -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData build
cp -R build/DerivedData/Build/Products/Release/mdview.app /Applications/
```

The first build fetches `swift-markdown` and `swift-cmark` and takes
about half a minute.

To make MDView the default app for Markdown files: in Finder, select a
`.md` file, choose File → Get Info, pick MDView under "Open with", and
click **Change All**.

**To update,** quit MDView, then in the `mdview` folder:

```bash
git pull
xcodebuild -project mdview.xcodeproj -scheme mdview -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData build
rm -rf /Applications/mdview.app
cp -R build/DerivedData/Build/Products/Release/mdview.app /Applications/
```

(Remove the old copy first: `cp -R` onto an existing app merges the two,
so files from the old version could be left behind.)

**Images and linked files.** macOS only lets MDView read the file you
open. When a page shows local images or links to other files, a bar
offers to allow that folder; choose it, or any folder above it, once.

## Layout

```
mdview.xcodeproj   the Xcode project (app target "mdview")
App/               the macOS app (AppKit, WebKit)
Packages/
  MDViewCore/      Markdown → HTML logic, no AppKit; tested with `swift test`
fixtures/          Markdown test files (spec.md, "Test files")
scripts/           open timing, offline check, icon drawing
docs/
  vision.md        why, for whom, what success looks like
  spec.md          what the product does, with acceptance criteria
  architecture.md  how it is built
  adr/             one file per architecture decision
  roadmap.md       milestones and ordered tasks
  checklist.md     every spec criterion and how it's checked
  progress.md      running log, updated at the end of each session
CLAUDE.md          standing instructions Claude reads every session
.claude/           shared Claude Code settings, commands and agents
```

## Developing

```bash
xcodebuild -project mdview.xcodeproj -scheme mdview build
```

```bash
swift test --package-path Packages/MDViewCore
```

Before a release, run through [docs/checklist.md](docs/checklist.md).

## License

MIT; see [LICENSE](LICENSE). MDView uses Apple's
[swift-markdown](https://github.com/swiftlang/swift-markdown) (Apache
License 2.0) and [swift-cmark](https://github.com/swiftlang/swift-cmark)
(BSD 2-Clause), which the build fetches from their own repositories.
