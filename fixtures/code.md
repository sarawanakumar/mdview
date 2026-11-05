# Code blocks

One block per supported language (spec 7.1), then blocks that must stay
plain (7.4) and blocks that are broken on purpose (7.6). Each language block
has keywords, strings, comments and numbers (7.2), and most have a string
or comment that spans lines (7.3).

## Swift

```swift
import Foundation

/* A block comment
   over two lines */
struct Greeter: Sendable {
    let name: String
    func greet(times: Int = 3) -> String {
        let banner = """
            Hello, \(name)!
            """
        return times > 0 ? banner : "" // never empty for 3
    }
}
```

## Python

```python
# Read a config file
def load(path, retries=2):
    """Load the file.

    Tries a few times."""
    for attempt in range(retries):
        if attempt is not None:
            return open(path).read()
    return 'none'
```

## JavaScript

```javascript
// Show the list
const items = [1, 2.5, 0x1f];
async function show(name = "list") {
  const text = `${name}:
${items.join(", ")}`;
  /* done */
  return text.length > 0 ? true : null;
}
```

## TypeScript

```ts
interface User {
  readonly id: number;
  name?: string; // optional
}
const limit = 100;
export function label(user: User): string {
  return `#${user.id} ${user.name ?? "anonymous"}`;
}
```

## Shell

```bash
#!/bin/bash
# Build every file given
set -euo pipefail
for file in "$@"; do
  if [ -f "$file" ]; then echo 'building' "$file"; fi
done
exit 0
```

## JSON

```json
{
  "name": "mdview",
  "version": 1.0,
  "offline": true,
  "plugins": null,
  "tags": ["viewer", "markdown"]
}
```

## YAML

```yaml
# Settings
name: mdview
enabled: true
retries: 3
note: "a # inside quotes"
list:
  - on
  - off  # trailing comment
```

## HTML

```html
<!-- A card,
     with a two-line comment -->
<div class="card" data-id='7'>
  <p>Text like "this" and 42 stays plain.</p>
</div>
```

## CSS

```css
/* Layout */
@media (max-width: 600px) {
  .card { margin: 0 auto; padding: 1.5rem; }
  .card::before { content: "\201C"; color: #1f2328; }
}
```

## Close relatives and tag case

```JSONC
{ "a": 1 /* tolerated */ }
```

```xml
<item id="1">Text</item>
```

## Plain blocks (7.4)

No tag:

```
let x = 1 // not coloured
```

Unknown tag:

```cobol
DISPLAY "not coloured".
```

Indented code:

    def not_coloured(): return 1

## Malformed blocks (7.6)

A Python string left open stops at the end of its line:

```python
print("never closed
x = 1
```

An unclosed block comment:

```javascript
/* never closed
const x = 1;
```

An unclosed template literal:

```js
const s = `open
still open
```

An unclosed HTML tag and comment:

```html
<div class="x
<!-- never closed
```

The text after the broken blocks is still normal.
