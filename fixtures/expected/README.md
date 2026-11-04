Expected HTML for the fixture files, one per fixture, at the same relative
path with `.html` instead of `.md` (for example `elements.html` for
`../elements.md`).

The tests in `Packages/MDViewCore` compare the renderer's output with
these. To write or update them after a deliberate change, run:

    MDVIEW_RECORD_EXPECTED=1 swift test --package-path Packages/MDViewCore

then review the diff before committing. This folder is skipped when the
tests look for fixtures.
