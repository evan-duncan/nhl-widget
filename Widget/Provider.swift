import AppKit
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let conference: Conference
    let standings: ConferenceStandings?
    var team: Team? = nil
    var logo: NSImage? = nil
    var staleSince: Date? = nil
    var favorite: String? = nil
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, conference: .west, standings: .sample) }

    func snapshot(for configuration: StandingsConfig, in context: Context) async -> Entry {
        placeholder(in: context)
    }

    func timeline(for configuration: StandingsConfig, in context: Context) async -> Timeline<Entry> {
        let conference = WidgetState.conference
        let loaded = await ConferenceStandings.load(conference)
        let standings = loaded?.standings
        let team = WidgetState.selectedTeam.flatMap { standings?.team($0) }
        // Detail page shows the selected team's logo; standings show the favorite's.
        let backgroundTeam = team?.abbrev ?? configuration.team?.rawValue
        var logo: NSImage?
        if let backgroundTeam { logo = await Logos.image(backgroundTeam) }
        let minutes: Double = loaded?.staleSince == nil && standings != nil ? 30 : 15
        return Timeline(entries: [Entry(date: .now, conference: conference, standings: standings, team: team, logo: logo,
                                        staleSince: loaded?.staleSince, favorite: configuration.team?.rawValue)],
                        policy: .after(.now.addingTimeInterval(minutes * 60)))
    }
}
