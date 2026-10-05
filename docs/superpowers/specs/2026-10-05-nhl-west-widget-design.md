# NHL Standings Widget — Design

> Originally written for a Western-Conference-only widget; updated to describe the shipped design
> (both conferences, team detail page, favorite team, cached fallback). Filename kept for history.

## Goal

A macOS large widget (desktop / Notification Center) showing current NHL wild-card standings for one
conference at a time, refreshing automatically. Personal use, not distributed.

## Data sources

- Standings: `GET https://api-web.nhle.com/v1/standings/now` (307-redirects to today's date;
  `URLSession` follows it). Response: `{ "standings": [Team] }`, all 32 teams.
- Logos: `https://assets.nhle.com/logos/nhl/svg/<ABBR>_light.svg` (SVG only; `NSImage` decodes it).

Team fields used:

| Field | Use |
|---|---|
| `conferenceAbbrev` | `"W"` / `"E"` filter |
| `divisionAbbrev` | `C` Central, `P` Pacific, `A` Atlantic, `M` Metropolitan |
| `divisionSequence`, `wildcardSequence` | ordering; `wildcardSequence == 0` = division top 3 |
| `teamAbbrev.default`, `teamName.default` | labels |
| `gamesPlayed`, `wins`, `losses`, `otLosses`, `points` | table columns |
| `pointPctg`, `goalFor`, `goalAgainst`, `goalDifferential` | detail page |
| `home*`, `road*`, `l10*` W/L/OTL | detail page splits |
| `streakCode`, `streakCount` (optional) | detail page streak; `–` when absent |
| `conferenceSequence`, `leagueSequence` | detail page ranks |

All fields except the streak are required; a missing field fails decoding. The API's sequences are
authoritative; there is no ranking logic of our own.

## Project layout

Generated with `xcodegen` from `project.yml`. Team `U3Q35XKQ69`, automatic signing, deployment target
macOS 15 (needed for `widgetAccentedRenderingMode`). The extension's `CFBundleVersion` follows
`CURRENT_PROJECT_VERSION`, which must be bumped when the widget's configuration or intents change,
because `chronod` caches widget descriptors per build number.

- `NHLWidget` (host app): one line of instructions; exists because widgets must ship inside an app.
- `StandingsWidget` (WidgetKit extension, sandboxed, `network.client`):
  - `Standings.swift`: `Team`, `Conference` (with persisted `current` and `selectedTeam`),
    `ConferenceStandings` (grouping, `team(_:)` lookup, `decode`, `fetchData`, `load` with cache fallback,
    `sample`).
  - `Teams.swift`: `FavoriteTeam` (32-case `AppEnum` for the picker) and `Logos` (URL + disk cache).
  - `StandingsWidget.swift`: intents, `Provider`, `StandingsView`, widget definition.
- `StandingsTests` (unit tests): decode/grouping for both conferences, team details, toggling,
  error cases, sample shape, favorite list vs. league, logo cache, standings cache fallback.

## State and interaction

Interactive widget buttons run `AppIntent`s inside the extension; state lives in the extension's
`UserDefaults`, and WidgetKit reloads the timeline after each intent.

| Intent | Trigger | Effect |
|---|---|---|
| `SwitchConference` | ‹ or › in the standings header | toggles `Conference.current` |
| `ShowTeam(abbrev)` | tap a team abbreviation | sets `Conference.selectedTeam` |
| `ShowStandings` | ‹ on the detail page | clears `Conference.selectedTeam` |

Configuration (`StandingsConfig`, Edit Widget): optional **Favorite Team**.

## Timeline

One entry per timeline, built by `Provider.timeline`:

1. `ConferenceStandings.load(Conference.current)`: fetch; on success save the raw response to
   `Caches/standings.json` and return it; on fetch or decode failure return the cached copy with
   `staleSince` set to its save time; with no cache, return nil.
2. Selected team = `selectedTeam` looked up in the loaded conference (nil if not found).
3. Background logo = selected team's logo on the detail page, otherwise the favorite's; loaded via
   `Logos.image`, which downloads once and serves from `Caches/<ABBR>.svg` after.
4. Reload after 30 minutes when fresh, 15 minutes when stale or failed.

Placeholder and snapshot use `ConferenceStandings.sample` (West, zeroed stats).

## Layout (`.systemLarge` only)

Content is top-aligned so the header row is at the same spot on both pages.

**Standings page**
- Header row spanning the width: `‹`, conference name centered, `›`.
- First division row carries the column labels: `Division … GP W-L-OT PTS`.
- Division (3 teams), division (3 teams), Wild Card (2 teams), a 2pt cutoff rule, remaining 8 teams.
- Type hierarchy: header 14pt bold, section headings 12pt bold, team rows 11pt (abbreviation indented,
  GP and W-L-OT secondary, PTS semibold), column labels 9pt semibold secondary. No row spacing; the
  content is ~305pt tall, close to the large widget's limit.
- Favorite team row: abbreviation in the accent color, stats bold and full strength.

**Detail page**
- Header row: `‹` (back) at left, team name centered.
- Sections Season (record, points in GP, points %), Rank (division, conference, league),
  Goals (for / against, differential), Form (home, road, last 10, streak).

**Both pages**
- Logo drawn behind the content at 20% opacity, in the content layer (not `containerBackground`) and
  with `.widgetAccentedRenderingMode(.fullColor)`, so it survives glass/tinted modes and keeps
  dark details (e.g. the Wild's trees) visible.
- When showing cached data, a small clock badge with the save time follows the header title.
- With no data at all: header plus `Couldn't load standings`.

## Out of scope

Other widget sizes, live scores, schedules, per-row team logos (tried; too small to read and made taps
slow), a points-from-playoff-line column (tried; removed).

## Verification

- `xcodebuild test -scheme StandingsTests` passes.
- Signed build registers the widget (`pluginkit -m -i com.evanduncan.NHLWidget.StandingsWidget`).
- On the desktop: both conferences switch, team detail opens and returns, favorite logo and highlight
  show, all 16 rows fit.
