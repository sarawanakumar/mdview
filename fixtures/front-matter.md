---
title: Front matter test
tags: [mdview, fixtures]
description: "This block must be hidden (spec 2.13)."
---

# Front matter

The YAML block above must not appear. Rendering starts with the heading.

A `---` further down is still a horizontal rule:

---

And this is a setext heading, not front matter
---

The end.
