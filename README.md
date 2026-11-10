# Quire

Quire is an iPad handwriting notebook whose canonical documents are ordinary,
user-owned files. Each `.quire` package contains a human-readable sidecar,
editable page drawings, optional PDF backgrounds, and a current flattened PDF.

The repository contains the platform-independent `QuireCore` package plus an
XcodeGen iPad application and PDF renderer. Apple-only targets are built by the
Xcode 27 workflow; the core remains buildable and testable on Windows.

## Implemented MVP foundation

- Files-first `.quire` packages in a user-chosen iCloud Drive or On My iPad folder.
- Blank, lined, grid, dotted, and Cornell paper in A4 and US Letter.
- PencilKit editing, tool picker, two-finger undo, page add/delete/reorder, and
  five-second/background autosave.
- PDF import with one editable drawing layer per source page.
- Flattened PDF regeneration and system share-sheet export.
- Offline Vision handwriting indexing, persisted search data, page jumps, and
  matching-region highlights.
- Three-notebook free tier and StoreKit 2 `quire.pro` one-time unlock.
- Public v1 format documentation and cross-platform core tests.

## Windows development

```powershell
./scripts/test-windows.ps1
```

Swift on Windows requires Visual Studio 2022 Build Tools with the **Desktop
development with C++** workload. The script enters the Visual Studio developer
shell automatically and keeps Swift caches inside the repository.

## Apple build

On an Xcode 27 Mac or CI runner:

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Quire.xcodeproj -scheme Quire \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The StoreKit product identifier is `quire.pro`. Configure it as a non-consumable
with Family Sharing before signed TestFlight builds. The full privacy policy is
published in [PRIVACY.md](PRIVACY.md).

## Signed IPA release builds

The `iPad app` workflow always produces an **unsigned verification IPA** for
download and inspection. It is not installable on an iPad. A secrets-gated job
also produces a signed App Store IPA when the repository provides these Actions
secrets:

- `APPLE_CERTIFICATE_BASE64` — base64-encoded Apple Distribution `.p12`.
- `APPLE_CERTIFICATE_PASSWORD` — password for that `.p12`.
- `APPLE_PROVISIONING_PROFILE_BASE64` — base64-encoded App Store provisioning profile.
- `APPLE_TEAM_ID` — the Apple Developer Team ID.
- `KEYCHAIN_PASSWORD` — a random, CI-only keychain password.

Set the repository Actions variable `IOS_SIGNING_ENABLED` to `true` only after
all five secrets are present. This activates the signed archive job; otherwise
the workflow remains green and publishes only the clearly labelled unsigned
verification IPA.

Set the external App Store privacy-policy URL to the published `PRIVACY.md` page
or a permanent hosted equivalent before submission.

See [FORMAT.md](FORMAT.md) for the public notebook format and
[DECISIONS.md](DECISIONS.md) for scope decisions.
