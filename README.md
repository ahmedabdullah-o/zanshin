# Zanshin

A quiet menu bar Pomodoro timer for macOS with a washi-paper palette, sumi-ink ensō, and vermilion break reminders.

## Features

- Lives in the menu bar (`LSUIElement`), no Dock icon, no windows on launch
- Focus sessions and short breaks, with a snooze action from the notification
- Native `UNUserNotificationCenter` integration (with action buttons)
- System-sound alarm (choose from `Glass`, `Submarine`, `Ping`, `Purr`, `Funk`, `Blow`, `Bottle`, `Tink`)
- The appearance switch applies the Washi light or Sumi dark palette to the timer and floating display. Menu bar icon contrast is available in the right-click menu.
- App Sandbox enabled, no network access

## Requirements

- macOS 26.5.2 or later
- Xcode 27, with the project set to Swift 5 language mode

## Build

```sh
xcodebuild \
  -project Zanshin.xcodeproj \
  -scheme Zanshin \
  -configuration Release \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM="" \
  build
```

Or open `Zanshin.xcodeproj` in Xcode and ⌘R.

## Running on your own Apple Developer account

The command above builds an ad hoc–signed app for local use. For builds signed with your own Apple Developer account:

1. Open `Zanshin.xcodeproj` in Xcode.
2. Select the `Zanshin` target → **Signing & Capabilities** → set your own Team.
3. Update `PRODUCT_BUNDLE_IDENTIFIER` (currently `com.githubusername.zanshin`) to one owned by your team.
4. Build & run.

> **Before you commit any pbxproj change, run `sh scripts/check-no-team-id.sh`.** The same check runs in CI on every push and PR.

## Project layout

```
Zanshin/
├── Zanshin/
│   ├── Zanshin.swift              # @main, AppDelegate, notification actions
│   ├── TimerModel.swift           # State, focus/break cycle, persistence
│   ├── TimerView.swift            # SwiftUI menu bar popover
│   ├── FloatingDisplayController.swift  # NSPanel host
│   ├── StatusBarController.swift  # NSStatusItem + menus
│   ├── SoundPlayer.swift          # System-sound alarm
│   ├── Theme.swift                # Palette + BladeTheme
│   ├── ZanshinGlyphs.swift        # SF Symbols + custom ensō drawing
│   ├── Info.plist                 # Empty; values come from INFOPLIST_KEY_*
│   └── Assets.xcassets/           # App icon and theme artwork
├── Zanshin.xcodeproj/
├── scripts/
│   └── check-no-team-id.sh        # CI guard
└── .github/workflows/ci.yml
```

## Conventions

### Swift style

- Swift 5.0, target macOS 26.5.2, SwiftUI + AppKit where it earns its keep
- 4-space indentation, no tabs, no trailing whitespace
- One type per top-level declaration, `final` by default
- `//` comments only when intent is non-obvious; avoid doc comments that restate the signature
- Prefer `enum` namespaces (`Theme`, `SoundPlayer`) over scattered globals
- File-scope helpers: `private` unless they need to be tested
- Imports at the top of the file, one per line, alphabetical

### Naming

- Types and protocols: `UpperCamelCase`
- Methods, properties, locals: `lowerCamelCase`
- Acronyms initialism-style: `URL`, `NSColor`, `UNUserNotificationCenter`
- Notification action identifiers: `SCREAMING_SNAKE` constants on `AppDelegate`
- UserDefaults keys: `lowerCamelCase`, prefixed by the owning type

### State & persistence

- `TimerModel` is the single source of truth; views are stateless functions of it
- User-tunable values go through `UserDefaults.standard` with a typed key constant
- No singletons besides `AppDelegate` and `SoundPlayer` (which is an `enum`)

### UI

- Colors come from `Theme` / `BladeTheme`; no raw `Color(red:green:blue:)` in views
- New strings go in the localizable catalog; no stringly-typed user-facing copy
- `LSUIElement` is `YES`; do not introduce a Dock icon without discussion

### Git

- Imperative mood subject lines (`Add SoundPlayer`, not `Added`)
- One logical change per commit
- `scripts/check-no-team-id.sh` must pass locally and in CI before push
- `.opencode/` is local tooling and must never be committed (see `.gitignore`)

### Xcode project

- `DEVELOPMENT_TEAM` stays `""`; CI rejects any PR that changes it
- `PRODUCT_BUNDLE_IDENTIFIER` is a placeholder (`com.githubusername.zanshin`); rename for your fork
- The project uses file-system synchronized groups (object version 90); new files under `Zanshin/` are picked up automatically — do not add them manually to `project.pbxproj`

## Theme artwork

Zanshin shares its Washi and Sumi palettes and woodblock prints with Komorebi. Both prints are public-domain reproductions from The Metropolitan Museum of Art.

- Washi uses Utagawa Hiroshige’s [Evening Snow on Mount Hira](https://www.metmuseum.org/art/collection/search/56897).
- Sumi uses Utagawa Hiroshige’s [Night Rain at Karasaki](https://www.metmuseum.org/art/collection/search/36531).

## License

Zanshin’s original work is available under the [MIT License](LICENSE). The woodblock prints are public domain.
