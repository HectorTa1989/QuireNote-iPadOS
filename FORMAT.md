# Quire notebook format v1

The Quire format is public so that a notebook remains useful without the app.
The format may be implemented by anyone. All user content remains the user's
property.

## Package layout

```text
MyNotebook.quire/
  notebook.json
  pages/<page-uuid>.drawing
  pages/<page-uuid>.bg.pdf
  MyNotebook.pdf
```

- `notebook.json` is UTF-8 JSON with sorted keys and indentation. Unknown keys
  must be ignored. Dates are ISO-8601 strings and UUIDs use their standard
  hyphenated representation.
- `pages/<page-uuid>.drawing` contains `PKDrawing.dataRepresentation()` bytes and
  is the editable source of truth on Apple platforms.
- `pages/<page-uuid>.bg.pdf` is present only for a page imported from PDF.
- `MyNotebook.pdf` is the latest flattened, portable representation. The app
  refreshes it when a notebook closes and after 60 seconds of idle time.

## `notebook.json`

Version 1 stores these required top-level keys:

| Key | Type | Meaning |
|---|---|---|
| `id` | UUID string | Stable notebook identity |
| `title` | string | Display title; not a file name |
| `paper` | object | Default paper kind and size |
| `pages` | array | Ordered page records |
| `createdAt` | ISO-8601 string | Creation instant |
| `schemaVersion` | integer | Currently `1` |

A page record contains `id`, `background`, and `strokesFile`, plus optional
`recognizedText`, `recognizedAt`, and `recognitionTokens`. Tokens contain the
recognized line and page-coordinate rectangles used for search highlighting.
A background uses one of these shapes:

```json
{ "type": "template", "paper": { "kind": "lined", "size": "a4" } }
```

```json
{ "type": "pdf", "file": "pages/<page-uuid>.bg.pdf", "pageIndex": 0 }
```

Paths are package-relative, use `/`, and may not contain `..` path components.
Readers must reject a future `schemaVersion` they do not understand rather than
silently rewriting it.

## Durability rules

`notebook.json` is written with an atomic same-directory replacement. Drawing
and PDF writers follow the same rule. The flattened PDF is a safety copy, not the
editable source of truth.

## License

This format specification is licensed under CC0-1.0. Code in this repository is
licensed separately when a project license is added.
