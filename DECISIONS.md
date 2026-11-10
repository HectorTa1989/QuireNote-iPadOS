# Decisions

## 2026-11-09 — Build QuireCore before Apple-only targets

The initial implementation follows section 4.1 of `prompt.md`. It begins with the
portable model, public format, search index, template geometry, and atomic
sidecar persistence because these can be verified on the owner's Windows machine.
No features outside the MVP have been added.

## 2026-11-09 — Keep platform geometry independent of CoreGraphics

`QuireCore` uses `QuireRect` and `QuirePoint` rather than `CGRect` so the package
compiles on Windows. Apple targets convert at their framework boundary. This
preserves a pure Swift core without changing the serialized values.

## 2026-11-09 — Use Vision as the first offline recognition engine

The iPadOS 27 PencilKit recognition API needs an Xcode 27 device spike before its
shipping API shape and background behavior are treated as stable. The MVP uses
Vision text recognition on an image of each changed drawing, which matches the
fallback explicitly allowed by the product brief. Recognition text and highlight
geometry are stored in the sidecar. Replacing the engine does not change the file
format or search UI.
