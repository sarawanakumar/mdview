# Elements

The reference file for spec section 2: every element mdview renders, plus
nested combinations. Each section names the spec criterion it checks.

## Headings (2.1)

# Heading level 1
## Heading level 2
### Heading level 3
#### Heading level 4
##### Heading level 5
###### Heading level 6

Setext heading level 1
======================

Setext heading level 2
----------------------

## Heading with *emphasis* and `code`

## Duplicate heading

## Duplicate heading

## Punctuation: "quotes", & ampersands, (brackets)!

## Paragraphs and line breaks (2.2)

This is one paragraph. It continues on the next line
without a blank line, so it stays in the same paragraph.

This paragraph ends its first line with two spaces  
so this text starts on a new line (a hard break).

A backslash at the end of a line also makes a hard break\
like this.

## Emphasis (2.3)

Text with *italic*, _also italic_, **bold**, __also bold__, ***bold italic***,
~~strikethrough~~ and ~single-tilde strikethrough~.

Nested: **bold with *italic* inside** and *italic with **bold** inside*.

Not emphasis: 2 * 3 * 4, snake_case_name, and \*escaped asterisks\*.

## Lists (2.4)

- Bulleted item one
- Bulleted item two
  - Nested level 2
    - Nested level 3
      - Nested level 4
- Bulleted item three

* Star bullets
+ Plus bullets

1. Numbered one
2. Numbered two
   1. Nested numbered
   2. Nested numbered
3. Numbered three

A separate list that starts at seven (a sentence in between, or it would
continue the list above):

7. Starts at seven
8. Then eight

- Loose list item with two paragraphs.

  Second paragraph of the same item.

- Next loose item.

## Task lists (2.5)

- [ ] Open task
- [x] Done task
- [X] Done task with a capital X
- [ ] Task with **bold** and a [link](https://example.com)
  - [x] Nested done task

## Blockquotes (2.6)

> A simple quote.

> A quote with two paragraphs.
>
> Second paragraph.

> Outer quote
>
> > Nested quote
> >
> > > Third level
>
> - A list in a quote
> - Second item
>
> ```swift
> let insideQuote = true
> ```

## Inline code (2.7)

Use `let x = 1` inline, or ``code with a ` backtick`` inside.

Characters stay literal in code: `<div>`, `&amp;`, `**not bold**`.

## Code blocks (2.8)

```swift
// Fenced, with a language tag.
struct Greeting {
    let text = "Hello, world!"
}
```

```
Fenced, no language tag.
```

~~~python
# Tilde fence.
print("hi")
~~~

    Indented code block (four spaces).
    Second line.

```text
A very long line that should scroll sideways inside its own box rather than wrapping or widening the window: 0123456789 0123456789 0123456789 0123456789 0123456789
```

## Tables (2.9)

| Left | Centre | Right | Default |
|:-----|:------:|------:|---------|
| a    | b      | c     | d       |
| **bold** | `code` | [link](https://example.com) | ~~strike~~ |
| escaped \| pipe | | empty cell left | |

| A very wide table | with many columns | so that it is wider than the window | and has to scroll sideways | on its own | without widening | the page |
|---|---|---|---|---|---|---|
| 1 | 2 | 3 | 4 | 5 | 6 | 7 |

## Horizontal rules (2.10)

Above three dashes.

---

Above three asterisks.

***

Above three underscores.

___

## Links (2.11)

An [inline link](https://example.com), one [with a title](https://example.com "Example title"),
a [reference link][ref], a [collapsed reference][], and an angle-bracket
autolink: <https://example.com/angle>. Email: <mailto:someone@example.com>.

A [relative link to another file](other.md), an [anchor link](#tables-29) and a
[link to a heading in another file](other.md#section).

[ref]: https://example.com/reference
[collapsed reference]: https://example.com/collapsed

## Bare web addresses (2.14)

Plain https://example.com/plain and http://example.com/http and www.example.com
become links. Trailing punctuation stays outside: https://example.com/end.
And in brackets (https://example.com/bracketed), or with a comma, https://example.com/comma, here.

Not in code: `https://example.com/in-code` stays plain.

## Punctuation as written (2.15)

"Straight double quotes", 'straight single quotes', two dashes -- and three ---,
and three dots... all stay exactly as typed.

## Images (section 3)

![A local image](images/sample.png)

![A remote image is never downloaded](https://example.com/remote.png)

## HTML is shown, not rendered (2.12)

Inline <b>bold tag</b>, <span style="color: red">a span</span> and
<script>alert("never runs")</script> all appear as text.

<div class="block">
An HTML block also appears as text.
</div>

## Escapes and entities

\# Not a heading, \- not a list, \[not a link\](nope).

Entities: &copy; &amp; &lt;tag&gt; &#169; &#x1F600;

## Mixed nesting

1. A numbered item with a quote:

   > Quoted inside a list.

2. A numbered item with code:

   ```json
   { "nested": true }
   ```

3. A numbered item with a table:

   | x | y |
   |---|---|
   | 1 | 2 |

The end.
