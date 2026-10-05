# NHL West Standings Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS large widget showing NHL Western Conference wild-card standings from `api-web.nhle.com`.

**Architecture:** `xcodegen` generates an Xcode project with three targets: a trivial SwiftUI host app, a WidgetKit extension, and an unhosted unit-test bundle. All data logic lives in `Widget/Standings.swift`, which is compiled into both the extension and the test bundle. The API's own `wildcardSequence`/`divisionSequence` drive ordering.

**Tech Stack:** Swift 5 language mode, SwiftUI, WidgetKit, XCTest, xcodegen, Xcode 27.

**Spec:** `docs/superpowers/specs/2026-10-05-nhl-west-widget-design.md`

## Global Constraints

- Team `U3Q35XKQ69`, `CODE_SIGN_STYLE: Automatic`, deployment target macOS 14.0.
- Bundle IDs: `com.evanduncan.NHLWidget` (app), `com.evanduncan.NHLWidget.StandingsWidget` (extension).
- Endpoint: `https://api-web.nhle.com/v1/standings/now`.
- Family `.systemLarge` only. Reload 30 min on success, 15 min on failure.
- Failure copy: `Couldn't load standings`.
- Extension entitlements: `com.apple.security.app-sandbox`, `com.apple.security.network.client`.
- Generated `NHLWidget.xcodeproj` and `build/` are git-ignored; `project.yml` is the source of truth.

## Review Focus

1. Offseason / empty `standings` array: user expects the failure message, not a blank widget. Pinned by `testNoWesternTeamsThrows` (Task 1).
2. Response missing a field we decode (API schema drift): user expects the failure message, not a crash. Pinned by `testMissingFieldThrows` (Task 1).
3. Gallery placeholder must look like real standings (3 / 3 / 10). Pinned by `testSampleShape` (Task 1).
4. 16 rows + headers overflowing the large widget: user expects every team visible. Checked visually in Task 2 Step 6.
5. Non-200 or HTML error page from the API: user expects the failure message. Handled by the status-code guard in `fetch()`; no network mock, so reviewer checks the guard by reading.

---

### Task 1: Data model, grouping, and tests

**Files:**
- Create: `.gitignore`
- Create: `project.yml` (test target only; Task 2 extends it)
- Create: `Widget/Standings.swift`
- Create: `Tests/StandingsTests.swift`
- Create: `Tests/fixture.json`

**Interfaces:**
- Produces:
  - `struct Team: Decodable, Hashable` with `abbrev: String`, `gamesPlayed`, `wins`, `losses`, `otLosses`, `points: Int`.
  - `struct WestStandings` with `central: [Team]`, `pacific: [Team]`, `wildCard: [Team]`, `static func decode(_ data: Data) throws -> WestStandings`, `static func fetch() async throws -> WestStandings`, `static let sample: WestStandings`.

- [ ] **Step 1: Install xcodegen and capture the fixture**

```bash
brew install xcodegen
mkdir -p Tests Widget App
curl -sfL https://api-web.nhle.com/v1/standings/2026-10-04 -o Tests/fixture.json
```

- [ ] **Step 2: Write `.gitignore` and `project.yml`**

`.gitignore`:
```
NHLWidget.xcodeproj/
build/
```

`project.yml`:
```yaml
name: NHLWidget
options:
  bundleIdPrefix: com.evanduncan
  deploymentTarget:
    macOS: "14.0"
settings:
  base:
    DEVELOPMENT_TEAM: U3Q35XKQ69
    CODE_SIGN_STYLE: Automatic
    SWIFT_VERSION: "5.0"
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  StandingsTests:
    type: bundle.unit-test
    platform: macOS
    sources: [Tests, Widget/Standings.swift]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
    scheme: {}
```

- [ ] **Step 3: Write the failing tests**

`Tests/StandingsTests.swift`:
```swift
import XCTest

final class StandingsTests: XCTestCase {
    func testFixtureGroupsWest() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "fixture", withExtension: "json"))
        let s = try WestStandings.decode(Data(contentsOf: url))
        XCTAssertEqual(s.central.map(\.abbrev), ["COL", "MIN", "UTA"])
        XCTAssertEqual(s.pacific.map(\.abbrev), ["EDM", "ANA", "SJS"])
        XCTAssertEqual(s.wildCard.map(\.abbrev), ["SEA", "VGK", "VAN", "WPG", "STL", "NSH", "LAK", "DAL", "CHI", "CGY"])
        XCTAssertEqual(s.pacific.first?.points, 5)
    }

    func testNoWesternTeamsThrows() {
        XCTAssertThrowsError(try WestStandings.decode(Data(#"{"standings":[]}"#.utf8)))
    }

    func testMissingFieldThrows() {
        XCTAssertThrowsError(try WestStandings.decode(Data(#"{"standings":[{"teamAbbrev":{"default":"COL"}}]}"#.utf8)))
    }

    func testSampleShape() {
        let s = WestStandings.sample
        XCTAssertEqual([s.central.count, s.pacific.count, s.wildCard.count], [3, 3, 10])
    }
}
```

Create an empty `Widget/Standings.swift` so the project generates.

- [ ] **Step 4: Run tests to verify they fail**

```bash
xcodegen && xcodebuild test -project NHLWidget.xcodeproj -scheme StandingsTests -destination 'platform=macOS' -allowProvisioningUpdates -quiet
```
Expected: compile FAIL, `cannot find 'WestStandings' in scope`.

- [ ] **Step 5: Implement `Widget/Standings.swift`**

```swift
import Foundation

struct Team: Decodable, Hashable {
    struct Localized: Decodable, Hashable { let `default`: String }

    let teamAbbrev: Localized
    let conferenceAbbrev: String
    let divisionAbbrev: String
    let divisionSequence: Int
    let wildcardSequence: Int
    let gamesPlayed: Int
    let wins: Int
    let losses: Int
    let otLosses: Int
    let points: Int

    var abbrev: String { teamAbbrev.default }
}

struct WestStandings {
    let central: [Team]
    let pacific: [Team]
    let wildCard: [Team]

    init(teams: [Team]) {
        let west = teams.filter { $0.conferenceAbbrev == "W" }
        func leaders(_ division: String) -> [Team] {
            west.filter { $0.divisionAbbrev == division && $0.wildcardSequence == 0 }
                .sorted { $0.divisionSequence < $1.divisionSequence }
        }
        central = leaders("C")
        pacific = leaders("P")
        wildCard = west.filter { $0.wildcardSequence > 0 }.sorted { $0.wildcardSequence < $1.wildcardSequence }
    }

    static func decode(_ data: Data) throws -> WestStandings {
        struct Response: Decodable { let standings: [Team] }
        let standings = WestStandings(teams: try JSONDecoder().decode(Response.self, from: data).standings)
        guard !standings.central.isEmpty || !standings.pacific.isEmpty else { throw URLError(.cannotParseResponse) }
        return standings
    }

    static func fetch() async throws -> WestStandings {
        let (data, response) = try await URLSession.shared.data(from: URL(string: "https://api-web.nhle.com/v1/standings/now")!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decode(data)
    }

    static let sample: WestStandings = {
        let rows = [("COL", "C", 0), ("MIN", "C", 0), ("UTA", "C", 0), ("EDM", "P", 0), ("ANA", "P", 0), ("SJS", "P", 0),
                    ("SEA", "P", 1), ("VGK", "P", 2), ("VAN", "P", 3), ("WPG", "C", 4), ("STL", "C", 5),
                    ("NSH", "C", 6), ("LAK", "P", 7), ("DAL", "C", 8), ("CHI", "C", 9), ("CGY", "P", 10)]
        return WestStandings(teams: rows.enumerated().map { i, row in
            Team(teamAbbrev: .init(default: row.0), conferenceAbbrev: "W", divisionAbbrev: row.1, divisionSequence: i,
                 wildcardSequence: row.2, gamesPlayed: 0, wins: 0, losses: 0, otLosses: 0, points: 0)
        })
    }()
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild test -project NHLWidget.xcodeproj -scheme StandingsTests -destination 'platform=macOS' -allowProvisioningUpdates -quiet
```
Expected: 4 tests PASS.

---

### Task 2: Host app and widget extension

**Files:**
- Modify: `project.yml` (add `NHLWidget` and `StandingsWidget` targets)
- Create: `App/NHLWidgetApp.swift`
- Create: `Widget/StandingsWidget.swift`

**Interfaces:**
- Consumes: `WestStandings.fetch()`, `WestStandings.sample`, `Team.abbrev`/`gamesPlayed`/`wins`/`losses`/`otLosses`/`points` from Task 1.

- [ ] **Step 1: Add targets to `project.yml`** (append under `targets:`)

```yaml
  NHLWidget:
    type: application
    platform: macOS
    sources: [App]
    dependencies:
      - target: StandingsWidget
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.evanduncan.NHLWidget
  StandingsWidget:
    type: app-extension
    platform: macOS
    sources: [Widget]
    info:
      path: Widget/Info.plist
      properties:
        CFBundleDisplayName: West Standings
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    entitlements:
      path: Widget/StandingsWidget.entitlements
      properties:
        com.apple.security.app-sandbox: true
        com.apple.security.network.client: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.evanduncan.NHLWidget.StandingsWidget
```

- [ ] **Step 2: Write `App/NHLWidgetApp.swift`**

```swift
import SwiftUI

@main
struct NHLWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Add the West Standings widget: right-click the desktop → Edit Widgets.")
                .padding()
        }
    }
}
```

- [ ] **Step 3: Write `Widget/StandingsWidget.swift`**

```swift
import SwiftUI
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let standings: WestStandings?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, standings: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let standings = try? await WestStandings.fetch()
            let minutes: Double = standings == nil ? 15 : 30
            completion(Timeline(entries: [Entry(date: .now, standings: standings)],
                                policy: .after(.now.addingTimeInterval(minutes * 60))))
        }
    }
}

struct StandingsView: View {
    let entry: Entry

    var body: some View {
        if let s = entry.standings {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 1) {
                GridRow {
                    Text("Western Conference").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                    Text("GP").gridColumnAlignment(.trailing)
                    Text("W-L-OT").gridColumnAlignment(.trailing)
                    Text("PTS").gridColumnAlignment(.trailing)
                }
                .foregroundStyle(.secondary)
                section("Central", s.central)
                section("Pacific", s.pacific)
                section("Wild Card", Array(s.wildCard.prefix(2)))
                Divider()
                rows(Array(s.wildCard.dropFirst(2)))
            }
            .font(.system(size: 11).monospacedDigit())
        } else {
            Text("Couldn't load standings").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ teams: [Team]) -> some View {
        Text(title).font(.caption.bold()).foregroundStyle(.secondary).padding(.top, 3)
        rows(teams)
    }

    private func rows(_ teams: [Team]) -> some View {
        ForEach(teams, id: \.abbrev) { t in
            GridRow {
                Text(t.abbrev).bold()
                Text("\(t.gamesPlayed)")
                Text("\(t.wins)-\(t.losses)-\(t.otLosses)")
                Text("\(t.points)").bold()
            }
        }
    }
}

@main
struct StandingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StandingsWidget", provider: Provider()) { entry in
            StandingsView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("West Standings")
        .description("NHL Western Conference wild-card standings.")
        .supportedFamilies([.systemLarge])
    }
}
```

- [ ] **Step 4: Generate, test, and build signed**

```bash
xcodegen
xcodebuild test -project NHLWidget.xcodeproj -scheme StandingsTests -destination 'platform=macOS' -allowProvisioningUpdates -quiet
xcodebuild build -project NHLWidget.xcodeproj -scheme NHLWidget -configuration Debug -derivedDataPath build -allowProvisioningUpdates -quiet
codesign -dv --entitlements - build/Build/Products/Debug/NHLWidget.app/Contents/PlugIns/StandingsWidget.appex 2>&1 | grep -E "TeamIdentifier|network.client"
```
Expected: tests PASS; build succeeds; output shows `TeamIdentifier=U3Q35XKQ69` and `com.apple.security.network.client`.

- [ ] **Step 5: Register the widget**

```bash
open build/Build/Products/Debug/NHLWidget.app
pluginkit -m -i com.evanduncan.NHLWidget.StandingsWidget
```
Expected: pluginkit prints the extension ID.

- [ ] **Step 6: Visual check (human)**

Right-click desktop → Edit Widgets → search "West Standings" → add the large size. Expected: header, Central 3, Pacific 3, Wild Card 2, a divider, 8 more teams. All 16 rows visible with nothing clipped, and live numbers rather than the zeros from `sample`. If it clips, reduce `size: 11` to `10` and `verticalSpacing` to `0`.
