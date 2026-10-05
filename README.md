# NHL Standings Widget

A macOS desktop / Notification Center widget showing NHL wild-card standings.

- Division top 3 for both divisions, then the wild-card race with a cutoff line after WC2
- Tap **‹ ›** to switch between the Western and Eastern conference
- Tap a team for a detail page: record, points %, division/conference/league rank, goals, home/road/last-10 records, streak
- Pick a favorite team (right-click the widget → **Edit Widget**) to show its logo in the background and highlight its row
- Shows the last good standings, with the time they were saved, when a refresh fails

## Requirements

- macOS 15 or later
- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An Apple Developer team (a free personal team works)

## Build

`project.yml` is the source of truth; the Xcode project is generated and git-ignored.

1. In `project.yml`, set `DEVELOPMENT_TEAM` to your team ID and `bundleIdPrefix` (and the two
   `PRODUCT_BUNDLE_IDENTIFIER` values) to a prefix you own.
2. Generate and build:

   ```sh
   xcodegen
   xcodebuild build -project NHLWidget.xcodeproj -scheme NHLWidget -configuration Release \
     -derivedDataPath build -allowProvisioningUpdates
   ```

3. Copy `build/Build/Products/Release/NHLWidget.app` to `/Applications` and open it once to register the widget.
4. Right-click the desktop → **Edit Widgets** → search "NHL Standings" → add the large size.

## Test

```sh
xcodebuild test -project NHLWidget.xcodeproj -scheme StandingsTests -destination 'platform=macOS'
```

Tests run against `Tests/fixture.json`, a saved standings response. `Tests/StubURLProtocol.swift` intercepts every HTTP request, so tests never call the NHL API.

## Project layout

| Path | Purpose |
|---|---|
| `Widget/Standings.swift` | Team model and conference/division grouping |
| `Widget/NHLAPI.swift` | `StandingsService`/`LogoService` protocols and NHL API implementations with caching |
| `Widget/Teams.swift` | Favorite-team picker |
| `Widget/Intents.swift` | `WidgetStateStore` (UserDefaults) and tap intents |
| `Widget/ViewModels.swift` | Display-ready standings and team-detail view models |
| `Widget/Provider.swift` | Timeline provider; builds view models from injected services |
| `Widget/StandingsView.swift` | Renders the view models |
| `Widget/StandingsWidget.swift` | Widget entry point and WidgetKit provider glue (not unit-tested) |
| `App/NHLWidgetApp.swift` | Minimal host app (widgets must ship inside an app) |
| `Tests/` | Unit tests and fixture |

## Troubleshooting

- **Widget doesn't pick up a change to its configuration or buttons.** macOS caches widget descriptions
  per build number. Bump `CURRENT_PROJECT_VERSION` in `project.yml`, rebuild, and reopen the app. If it
  still looks stale, remove the widget and add it again.
- **Widget disappeared.** It is registered from wherever the app was last opened. If that copy was
  deleted (for example a cleaned `build/` folder), open the app from `/Applications` again.

## Data and trademarks

Standings and logos come from the NHL's public but undocumented API (`api-web.nhle.com`) and asset
server (`assets.nhle.com`); either may change without notice. This project is not affiliated with or
endorsed by the NHL. NHL and team names and logos are trademarks of the NHL and its teams.

## License

[MIT](LICENSE)
