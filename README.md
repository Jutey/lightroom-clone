# Darkroom Lite

A free, Lightroom-style photo culling and editing app for macOS, built with Swift and SwiftUI. Darkroom Lite lets you import folders of photos, cull and rate them, make non-destructive edits, and export the results — without ever touching your original files.

## Features

- **Library**: import a folder as a project, browse photos in a grid/filmstrip or single-photo "loupe" view, with before/after compare.
- **Culling**: star ratings, pick/reject flags, color labels, search/filter, fully customizable keyboard shortcuts.
- **Editing** (all non-destructive): Exposure, Contrast, Highlights, Shadows, Whites, Blacks, Saturation, Vibrance, Temperature, Tint, Clarity/Texture/Dehaze, Sharpening, Noise Reduction, Vignette, Grain, Black & White, Tone Curve, HSL color mixer, color grading wheels, lens corrections.
- **Crop & geometry**: draggable crop with aspect-ratio presets, straighten, rotate/flip, vertical/horizontal perspective correction, guide overlays.
- **Non-destructive workflow**: edits are stored in a local SwiftData database (with optional JSON sidecar files); originals are never modified, moved, or deleted. Snapshots/history, copy-paste edits, and batch apply are all supported.
- **Export**: choose scope (selected/picked/all), format and quality, optional resizing, destination, and filename suffix.
- **Performance**: thumbnail caching and lazy loading designed to handle libraries of hundreds to thousands of photos.

## Requirements

- macOS Sequoia 15.0 or later (to run the app)
- Xcode 16 or later (to build from source)

## Option 1: Download a pre-built copy from GitHub Actions

Every push to this repository is automatically built on a macOS runner via GitHub Actions. You can download the resulting app without installing Xcode:

1. Go to the repository's **Actions** tab on GitHub.
2. Click the most recent successful run of the **Build and Test** workflow (green checkmark).
3. Scroll down to the **Artifacts** section and download **DarkroomLite-macOS** — this downloads a `DarkroomLite.zip`.
4. Unzip it to get `DarkroomLite.app`, then move it to `/Applications` (or anywhere you like).

### Bypassing Gatekeeper (first launch)

CI builds are **ad-hoc signed** (not signed with an Apple Developer ID and not notarized), so macOS Gatekeeper will refuse to open the app normally and may say it's "damaged" or from an "unidentified developer." To run it anyway:

- **Right-click (or Control-click) the app → Open**, then click **Open** again in the dialog that appears, **or**
- Remove the quarantine flag from Terminal:
  ```sh
  xattr -cr /Applications/DarkroomLite.app
  ```

This is a one-time step per downloaded build.

## Option 2: Build from source

```sh
git clone https://github.com/jutey/lightroom-clone.git
cd lightroom-clone
open DarkroomLite.xcodeproj
```

In Xcode, select the **DarkroomLite** scheme and press **Run** (⌘R). The project uses ad-hoc code signing (`CODE_SIGN_IDENTITY = -`) so it builds and runs locally without an Apple Developer account.

### Building from the command line

```sh
xcodebuild build \
  -project DarkroomLite.xcodeproj \
  -scheme DarkroomLite \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

### Running tests

```sh
xcodebuild test \
  -project DarkroomLite.xcodeproj \
  -scheme DarkroomLite \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Project structure

```
DarkroomLite/                  App target
  Models/                      SwiftData models (Project, Photo, Edit, Crop/Perspective settings, ...)
  ViewModels/                  App state, library state, settings store
  Services/                    Import, export, thumbnails, RAW decoding, security-scoped file access
  Views/
    Sidebar/                   Project/album navigation
    Library/                   Grid, filmstrip, loupe/compare views
    Editor/                    Edit panel and sliders
    Geometry/                  Crop & perspective tools
    Export/                    Export sheet
    Toolbar/                   Main toolbar
    Settings/                  Preferences window (8 tabs)
  Utilities/                   Keyboard shortcut capture, helpers
  Assets.xcassets/             App icon, accent color
DarkroomLiteTests/             Unit tests
.github/workflows/             CI: build + test on macOS, uploads app artifact
```

## Contributing / development workflow

1. Create a branch off `main` for your change.
2. Commit with clear, descriptive messages.
3. Push your branch and open a pull request.

The GitHub Actions workflow (`.github/workflows/build.yml`) runs the unit tests and a Release build on every push and pull request, and publishes the built app as a downloadable artifact (see Option 1 above).

## Privacy & data

Darkroom Lite never copies, moves, renames, or deletes your original photo files. Imported folders are accessed via macOS security-scoped bookmarks, and all edits/ratings/metadata live in a local SwiftData store under Application Support, with optional JSON sidecar files alongside your photos if enabled in Settings.
