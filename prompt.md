# Quire — iPadOS build plan and implementation prompt
> Owner constraints: develops on Windows 10, owns no Mac, wants near-zero hardware spend. Section 8 is the workflow. This is the largest build in the set (about 10 weeks to v1.0), chosen because it targets the largest proven iPad market.

## 0. How to use this document

You are building **Quire**, a handwritten-notes app for iPad whose notebooks are ordinary files you own. You buy it once. Every notebook is a folder in Files or iCloud Drive holding a PDF plus a small JSON sidecar, so it opens in any PDF reader. Your notes survive if Quire disappears.

Quire does not try to beat Goodnotes on features. It wins on three promises: **you pay once, the files are yours, and handwriting search works offline.** Build section 4.1 first and do not add features outside section 4 without a written reason in `DECISIONS.md`.

Quire is separate from MarginRecall (round 1, PDF margins to flashcards). Quire has no study or flashcard features.

---

## 1. One-line pitch

**Handwritten notebooks that are just files: PDF you own, search that reads your handwriting, one price forever.**

---

## 2. Why this app (evidence)

### 2.1 Demand signals

| # | Signal | Source | Date | Engagement |
|---|--------|--------|------|------------|
| 1 | "GoodNotes 5 users were forced to repurchase or subscribe when Goodnotes 6 launched." | [Paperlike comparison](https://paperlike.com/blogs/paperlikers-insights/app-review-goodnotes-vs-notability) | 2026-08 | editorial |
| 2 | Notability review: "I've even considered moving to a different notes system" (subscription tiers up to $99.99/yr). | [Notability on the App Store](https://apps.apple.com/us/app/notability-notes-pdf/id360593530) | 2026 | 457K ratings |
| 3 | Goodnotes has 25M monthly active users and now sells Essential $11.99/yr, Pro $35.99/yr, an Apple-only one-time tier at $28.99-35.99, and an AI Pass at $9.99/month. | [TechCrunch](https://techcrunch.com/2025/09/23/goodnotes-collaborative-docs-and-ai-assitant-to-cater-to-professional-users/), [Goodnotes on the App Store](https://apps.apple.com/us/app/goodnotes-6/id1444383602) | 2025-09 | 455K ratings |
| 4 | Nebo ($14.99 one-time) users complain: "Why is background sync not enabled?" | [Nebo on the App Store](https://apps.apple.com/us/app/nebo-notes-pdf-annotations/id1119601770) | 2026 | 39K ratings |
| 5 | Data loss fear in iPad creative apps: "I've had to delete a year worth of artwork because of this storage or backup issues." | [Procreate on the App Store](https://apps.apple.com/us/app/procreate/id425073498) | 2026 | review |
| 6 | Craig Mod on iPad: "Almost anything that doesn't involve the Apple Pencil... could be done better on a MacBook." Pencil work is the iPad's reason to exist. | [Craig Mod](https://craigmod.com/essays/ipad_neo/) | 2026-04 | essay |

**Not found:** Reddit thread bodies (r/GoodNotes, r/Notability, r/ipad were blocked to the crawler), and a count of users who left Goodnotes. Before launch, open r/GoodNotes and r/Notability by hand and collect ten dated complaints for the marketing page.

### 2.2 Competitors and the gap

| App | Price | Where it stops |
|-----|-------|----------------|
| Goodnotes 6 | subscription or Apple-only one-time; AI extra | Proprietary format; repurchase history (signal 1) |
| Notability | up to $99.99/yr | Subscription; proprietary format |
| Nebo | $14.99 one-time | Conversion-first; sync complaints |
| Apple Notes | free | Handwriting inside Notes only; no notebook paper, weak PDF workflow, no file ownership |
| Freeform | free | Canvas, not notebooks |
| CollaNote, Noteshelf, others | free or low | Proprietary formats, ads or upsells |

**The gap Quire fills:** a notebook app where the canonical storage is standard PDF in a folder you choose, handwriting search runs on the device, and the price is paid once. Nobody in the table offers all three.

### 2.3 Why now

- **PencilKit gained on-device handwriting recognition "across a wide range of alphabets and languages"** in the 27 releases, the same technology behind Notes and Freeform ([WWDC26 session 203](https://developer.apple.com/videos/play/wwdc2026/203/), [Apple iPadOS What's New](https://developer.apple.com/ipados/whats-new/)). Handwriting search used to need a licensed engine (MyScript powers Nebo). Now it is a system API.
- **PaperKit** (iPadOS 26) gives a full markup layer (shapes, text boxes, images) on top of PencilKit ([WWDC25 session 285](https://developer.apple.com/videos/play/wwdc2025/285/)).
- iPadOS 26 windowing lets two notebooks sit side by side; iPadOS 27 made file transfers to USB drives up to 5x faster, which matters for a files-first app ([Apple newsroom](https://www.apple.com/newsroom/2026/09/major-updates-for-apples-software-platforms-are-now-available/)).

### 2.4 Honest market sizing

The market is huge (Goodnotes alone has 25M monthly users), and a small slice of it is worth a lot. The incumbents are also excellent and well funded. Target **$2-8K/month by month 9** from people who were burned by the Goodnotes 6 transition, lawyers, researchers and students who care about their files, and privacy-minded users. This is a long-haul product; do not start it expecting a six-week payoff.

---

## 3. Target user and jobs to be done

**Primary:** students and professionals (law, research, engineering, teaching) who write by hand daily on an iPad with Apple Pencil and have been through a subscription change they resented.

Jobs:
1. "Take lecture or meeting notes on lined or grid paper, fast, with a pen that feels right."
2. "Annotate a PDF handout and keep it with my notes."
3. "Find the page where I wrote 'Fourier' three months ago."
4. "Know that my notes are PDFs in my iCloud Drive, readable anywhere, forever."
5. "Pay once."

---

## 4. Scope

### 4.1 MVP (weeks 1-6, TestFlight)

- **Library:** notebooks as folders in a user-chosen location (iCloud Drive or On My iPad), grid of covers, sort and search.
- **Notebook:** page templates (blank, lined, grid, dotted, Cornell) at A4 and US Letter; add, delete and reorder pages; PencilKit canvas per page with the system tool picker; palm rejection; zoom and scroll; undo.
- **PDF import:** each imported PDF page becomes a notebook page with the PDF as background; annotate on top.
- **Storage format:** see section 6.4. Autosave every 5 s and on background; crash-safe atomic writes.
- **Handwriting search:** background recognition of each page's strokes; an index stored in the sidecar; search highlights matching strokes and jumps to the page.
- **Export:** share a notebook as a flattened PDF.
- **Purchase:** free tier covers 3 notebooks; Pro one-time unlock (section 7).

### 4.2 v1.0 (weeks 7-10, App Store)

- PaperKit markup: shapes, text boxes, images, stickers on pages.
- Lasso select, move, resize, recolor; copy strokes between pages.
- Two-window workflow (reference PDF beside a notebook) with iPadOS 26 windowing.
- Outline: page titles recognized from the first handwritten line.
- Import from Goodnotes exports (they export PDF); guide users through exporting their library.
- Localizations: English, Vietnamese, Spanish, German, Japanese, Chinese (recognition coverage per language verified).

### 4.3 v1.x

- Mac app (Catalyst or native) to read and search the same folders.
- Audio recording synced to strokes.
- Templates marketplace (free packs only at first).

### 4.4 Non-goals

- Real-time collaboration, accounts, our own cloud.
- AI features that need a server (on-device summaries may come later through Foundation Models).
- Flashcards and study modes (MarginRecall covers those).

---

## 5. UX: screens and flows

1. **Library:** sidebar (locations, recent, search), cover grid, "+" for a notebook or a PDF import.
2. **Notebook:** full-bleed page, minimal toolbar (pen, highlighter, eraser, lasso, undo, page menu); page strip at the bottom; two-finger tap to undo.
3. **Search:** type a word; results list with page thumbnails and highlighted strokes.
4. **Settings:** default paper, pen feel (latency, pressure curve), storage location, Pro.
5. **Onboarding:** one screen explaining "your notebooks are files", a folder picker, and a sample notebook.

Performance budget: pen latency must match the system (PencilKit handles this; do not wrap the canvas in heavy SwiftUI updates). Page switches under 100 ms.

---

## 6. Architecture and tech stack

### 6.1 Targets

- `Quire` (iPadOS 17+, SwiftUI shell with UIKit-hosted `PKCanvasView`; handwriting recognition and PaperKit gated with `#available`).
- `QuireCore` (SwiftPM, pure Swift, Linux and Windows testable): notebook model, sidecar schema and migrations, search index, template geometry, file layout.
- `QuireRender` (iOS-only): PDF composition (background + strokes) with PDFKit and Core Graphics.
- Tests: `QuireCoreTests`, `QuireRenderTests`, `QuireUITests`.

### 6.2 Frameworks

PencilKit (`PKCanvasView`, `PKDrawing`, handwriting recognition APIs from the 27 SDK), PaperKit (v1.0), PDFKit, UniformTypeIdentifiers, `UIDocument`/`NSFileCoordinator` for iCloud Drive safety, BackgroundTasks for indexing, StoreKit 2.

### 6.3 Data model (QuireCore)

```swift
struct Notebook: Codable { var id: UUID; var title: String; var paper: Paper; var pages: [PageRef]; var createdAt: Date; var schemaVersion: Int }
struct PageRef: Codable { var id: UUID; var background: Background; var strokesFile: String; var recognizedText: String?; var recognizedAt: Date? }
enum Background: Codable { case template(Paper), pdf(file: String, pageIndex: Int) }
struct SearchHit { let pageID: UUID; let range: Range<String.Index>; let strokeBounds: [CGRect] }
```

### 6.4 File format (the product's core promise; freeze it before week 3)

```
MyNotebook.quire/            (a folder; a package UTI so Files shows it as one item)
  notebook.json              (Notebook, human-readable)
  pages/<uuid>.drawing       (PKDrawing data, the editable source of truth)
  pages/<uuid>.bg.pdf        (imported background page, if any)
  MyNotebook.pdf             (flattened, regenerated on close and every 60 s of idle)
```

The flattened PDF is always present and current, so any PDF reader can open the notes even without Quire. Document the format publicly in `FORMAT.md` under a permissive licence: "your data is yours" is a claim that must be checkable.

### 6.5 Hard parts and spikes

- **Recognition API shape and cost:** week 1 spike on the 27 SDK: per-page latency, language coverage, whether it runs in the background. Fall back to Vision text recognition on a rendered page image if the stroke API cannot index in the background.
- **iCloud Drive conflicts:** use `NSFileCoordinator` and `NSFilePresenter`; on conflict keep both versions and show them.
- **Large PDFs:** lazy page loading; render backgrounds at screen scale; cap memory.
- **Pen feel:** cannot be judged in the simulator (section 8).

---

## 7. Monetization

- **Free:** 3 notebooks, all tools, search, export.
- **Pro, one-time $19.99** (launch $14.99): unlimited notebooks, PaperKit tools, two-window workflows, templates. Family Sharing enabled.
- Positioning: "Pay once. Keep your files." Compare openly with subscription totals over three years.
- StoreKit 2 non-consumable `quire.pro`. Owner bypass: Pro in `DEBUG` and sandbox/Xcode environments.
- Future paid major versions are allowed (a v2 upgrade price), but v1 buyers keep every v1 feature forever. Write that in the store description.

---

## 8. Build, test and ship

Shared setup: [TOOLING-no-Mac-2026-09-21.md](../../TOOLING-no-Mac-2026-09-21.md).

Specific to Quire:
- **Windows:** `QuireCore` including the format and index, fully tested.
- **CI:** iPad simulator UI tests. Scripted strokes are injected by constructing `PKDrawing` objects in tests, so rendering, saving, reopening and search can all be tested without a Pencil. The screenshots job captures App Store images.
- **Cloud Mac (about 25 hours):** recognition spike, iCloud Drive conflict tests between two simulators, performance profiling in Instruments.
- **Real iPad and Apple Pencil are needed for pen feel.** This cannot be faked. Options: TestFlight testers (students from r/GoodNotes and r/students, 10-15 people), or an iPad 11th gen at $449 plus an Apple Pencil (USB-C) if the owner wants to dogfood ([Apple iPad](https://www.apple.com/shop/buy-ipad/ipad)).

---

## 9. Testing plan and acceptance criteria

### 9.1 Unit (QuireCore)

Format round-trips and migrations; index updates; template geometry; atomic save under simulated crashes.

### 9.2 UI and render (simulator)

A 200-page notebook opens in under 1 s; flattened PDF matches the canvas (pixel diff under 1%); search finds injected handwriting fixtures.

### 9.3 Tester checklist (real iPads)

Pen latency indistinguishable from Apple Notes (blind comparison by 5 testers); no data loss across 2 weeks of daily use; iCloud sync between two iPads without conflicts in normal use.

### 9.4 MVP acceptance criteria

1. 9.1 and 9.2 green.
2. The notebook folder opens as a readable PDF in Files' Quick Look and on Windows.
3. Five testers complete two weeks with zero lost pages.
4. Free and Pro gates verified with the StoreKit configuration.

---

## 10. App Store submission

- **Category:** Productivity. **Name:** Quire (verify; fallback "Quire: Notes You Own").
- **Subtitle:** "Handwritten notes. Your files. Pay once."
- Keywords: handwriting, notes, notebook, apple pencil, pdf annotate, goodnotes alternative is not allowed (no competitor names), lecture notes, planner, journal.
- **Privacy label:** Data not collected.
- **Review notes:** explain the file format and include a sample notebook.
- **Risks:** 4.3(b) saturated category: the review notes lead with file ownership, the open format document and one-time pricing.

---

## 11. Launch and distribution

1. Week 7: TestFlight with students and researchers.
2. Week 10: App Store launch timed for a semester start if possible (January or late August); posts in r/ipad, r/GoodNotes (follow the rules), r/students, r/GradSchool; publish `FORMAT.md` and a "how to move from Goodnotes" guide.
3. Ongoing: YouTube "study with me" and iPad-setup creators; send free Pro codes.
4. Metrics: installs, Pro conversion (target 5-8%), notebooks per user, day-30 retention.

---

## 12. Milestones

| Week | Deliverable |
|------|-------------|
| 1 | Repo, CI; format frozen in `QuireCore`; recognition spike. |
| 2-3 | Library, notebook, canvas, templates, autosave. |
| 4 | PDF import, flattened PDF, export. |
| 5 | Handwriting index and search. |
| 6 | StoreKit, TestFlight. **MVP criteria 1, 2, 4.** |
| 7-9 | PaperKit tools, lasso, two-window, outline, localizations; tester feedback. |
| 10 | Submission and launch (criterion 3 met). |

---

## 13. Risks and mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Incumbents are much better at everything else | Certain | Compete on ownership and price, not features; stay focused. |
| Pen feel below expectations | Medium | PencilKit defaults; testers from week 7. |
| Recognition API limits | Medium | Vision fallback. |
| iCloud conflicts corrupt notes | Medium | File coordination, keep-both policy, flattened PDF as a safety copy. |
| Long build before revenue | High | Ship MVP at week 6 to TestFlight; launch by week 10. |

---

## 14. Open questions for the owner

1. Do you have an iPad and Apple Pencil for dogfooding?
2. Should the free tier be 3 notebooks, or unlimited with Pro-only tools?
3. Name check on "Quire"?

---

## 15. Sources

- Demand and competitors: [Paperlike](https://paperlike.com/blogs/paperlikers-insights/app-review-goodnotes-vs-notability), [Notability](https://apps.apple.com/us/app/notability-notes-pdf/id360593530), [Goodnotes](https://apps.apple.com/us/app/goodnotes-6/id1444383602), [TechCrunch on Goodnotes](https://techcrunch.com/2025/09/23/goodnotes-collaborative-docs-and-ai-assitant-to-cater-to-professional-users/), [Nebo](https://apps.apple.com/us/app/nebo-notes-pdf-annotations/id1119601770), [Procreate](https://apps.apple.com/us/app/procreate/id425073498), [Notability pricing](https://notability.com/pricing), [Craig Mod](https://craigmod.com/essays/ipad_neo/)
- APIs: [WWDC26 PencilKit session 203](https://developer.apple.com/videos/play/wwdc2026/203/), [WWDC25 PaperKit session 285](https://developer.apple.com/videos/play/wwdc2025/285/), [iPadOS What's New](https://developer.apple.com/ipados/whats-new/), [WWDC26 iPadOS guide](https://developer.apple.com/wwdc26/guides/ipados)
- Platform: [Apple newsroom 2026-09](https://www.apple.com/newsroom/2026/09/major-updates-for-apples-software-platforms-are-now-available/), [RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps-2026-business/)
