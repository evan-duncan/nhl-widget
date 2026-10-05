# NHL Western Conference Standings Widget — Design

## Goal

A macOS large widget (Notification Center / desktop) showing current NHL Western
Conference standings in wild-card format, refreshing automatically. Personal use,
not distributed.

## Data source

`GET https://api-web.nhle.com/v1/standings/now` (307-redirects to today's date;
`URLSession` follows it). Response: `{ "standings": [Team] }`.

Fields used per team:

| Field | Use |
|---|---|
| `conferenceAbbrev` | keep only `"W"` |
| `divisionAbbrev` | `"C"` Central, `"P"` Pacific |
| `divisionSequence` | order within division |
| `wildcardSequence` | `0` = division top 3, `1…10` = wild-card order |
| `teamAbbrev.default` | team label |
| `gamesPlayed`, `wins`, `losses`, `otLosses`, `points` | columns |

No ranking logic of our own; the API's sequences are authoritative.

## Project layout

Generated with `xcodegen` from `project.yml`. Team `U3Q35XKQ69`, automatic signing,
deployment target macOS 14.

- `NHLWidgetApp` (host app): SwiftUI window with one line of instructions. Exists only
  because widget extensions must be embedded in an app.
- `StandingsWidget` (WidgetKit extension): sandboxed, `com.apple.security.network.client`.
  - `Standings.swift`: `Codable` model, fetch, and grouping into
    `central` (3), `pacific` (3), `wildCard` (10).
  - `StandingsWidget.swift`: `TimelineProvider`, `StaticConfiguration`, view.
- `StandingsTests` (unit tests): decodes `fixture.json` (captured 2026-10-05) and checks grouping.

## Widget behavior

- Family: `.systemLarge` only.
- Layout: header "Western Conference"; sections Central, Pacific, Wild Card; a divider
  after WC2. Columns: team, GP, W-L-OTL, PTS; monospaced digits.
- Timeline: one entry; reload after 30 minutes on success, 15 minutes on failure.
- Failure: entry carries no data; view shows "Couldn't load standings".
- Placeholder/snapshot: built from bundled sample data so the gallery renders offline.

## Out of scope

Team logos, conference picker, offline cache of last-good data, other widget sizes.

## Verification

- `xcodebuild test` passes (decode + grouping).
- `xcodebuild build` of app succeeds signed; launching the app registers the widget;
  widget appears in Edit Widgets and shows live data.
