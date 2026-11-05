# Links

The test file for spec section 4. Relative paths are relative to this
file. Clicking a local file outside a granted folder asks for folder
access first (4.2).

## On this page (4.3)

- [Jump to the end](#the-end)
- [Jump to a heading by this file's name](links.md#web-and-mail)
- [This file, no anchor (does nothing)](links.md)

## Other Markdown files (4.2, 4.3)

- [Elements](elements.md)
- [Elements, tables section](elements.md#tables-29)
- [A file in a subfolder](edge/valid.md)
- [Through the parent folder](../fixtures/front-matter.md)
- [Space in the name](edge/with%20space.md)
- [Missing Markdown file (shows "not found")](missing.md)

## Other files (4.4)

- [An image, opens in its default app](images/sample.png)
- [A folder, opens in Finder](images/)
- [A plain text file](edge/plain.txt)
- [Missing other file](missing.pdf)

## Web and mail (4.1)

- [A web page](https://example.com)
- [Plain HTTP](http://example.com)
- [Email](mailto:someone@example.com)
- Bare address: https://example.com/bare
- Angle-bracket autolink: <https://example.com/angle>

## Reference-style

[Reference to elements][elements] and [reference to the web][web].

[elements]: elements.md
[web]: https://example.com/reference

## Not followed

- [JavaScript (shown as text only)](javascript:alert(1))
- [Data URL (shown as text only)](data:text/html,hello)
- [FTP (no link)](ftp://example.com/file)

## The end

Hovering over any link shows where it goes (4.5).
