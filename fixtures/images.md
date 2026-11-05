# Images

The test file for spec section 3. Paths are relative to this file, so it
works wherever the repository is. Absolute paths and `file://` URLs are
covered by unit tests, since they depend on where the repository lives.

All local images need folder access to this folder (spec 9.5); until it's
granted, they show their alt text.

## Local images (3.1, 3.3)

Relative: ![The sample image](images/sample.png)

With `./`: ![The sample image again](./images/sample.png)

Through the parent folder: ![Via the parent folder](../fixtures/images/sample.png)

Space in the name, percent-encoded: ![Space encoded](images/with%20space.png)

Space in the name, in angle brackets: ![Space in brackets](<images/with space.png>)

With a title: ![Has a title](images/sample.png "Hover title")

No alt text (the file name stands in if it can't be shown): ![](images/sample.png)

## Sizes (3.4)

Small images show at their natural size: ![Small](images/sample.png)

A wide image (2400 × 300) scales down to fit the column:

![Wide image](images/wide.png)

## Inside other elements

In a link: [![Linked image](images/sample.png)](https://example.com)

In a table:

| Image | Name |
|-------|------|
| ![In a table](images/sample.png) | sample.png |

In a list:

- ![In a list](images/sample.png) beside text

In a quote:

> ![In a quote](images/sample.png)

## Never shown (3.5, 3.6)

Missing file: ![This file does not exist](images/missing.png)

Not an image: ![A Markdown file, not an image](elements.md)

Remote, never downloaded: ![Remote image](https://example.com/remote.png)

Remote over plain HTTP: ![Remote over HTTP](http://example.com/remote.png)

Unsafe source: ![Script source](javascript:alert(1))

Inline data: ![Data source](data:image/png;base64,iVBORw0KGgo=)
