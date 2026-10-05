import AppKit
import WidgetKit

struct Entry: TimelineEntry {
    enum Content {
        case standings(StandingsViewModel)
        case detail(TeamDetailViewModel)
        /// No fresh or cached standings; the header still shows the conference so it can be switched.
        case failed(title: String)
    }

    let date: Date
    let content: Content
    var logo: NSImage? = nil
    /// False when showing cached data or nothing, so the timeline retries sooner.
    var isFresh = true
}

struct Provider {
    var standingsService: any StandingsService = NHLStandingsService()
    var logoService: any LogoService = NHLLogoService()
    var state: any WidgetStateStore = UserDefaultsWidgetState()

    static let placeholder = Entry(date: .now,
                                   content: .standings(StandingsViewModel(standings: .sample, favorite: nil, staleSince: nil)))

    func timeline(favorite: String?, now: Date = .now) async -> Timeline<Entry> {
        let entry = await entry(favorite: favorite, now: now)
        let minutes: Double = entry.isFresh ? 30 : 15
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(minutes * 60)))
    }

    func entry(favorite: String?, now: Date = .now) async -> Entry {
        let conference = state.conference
        guard let loaded = await standingsService.load(conference) else {
            return Entry(date: now, content: .failed(title: conference.name), logo: await logo(favorite), isFresh: false)
        }
        let isFresh = loaded.staleSince == nil
        // Detail page shows the selected team's logo; standings show the favorite's.
        if let team = state.selectedTeam.flatMap(loaded.standings.team) {
            return Entry(date: now, content: .detail(TeamDetailViewModel(team: team, staleSince: loaded.staleSince)),
                         logo: await logo(team.abbrev), isFresh: isFresh)
        }
        let model = StandingsViewModel(standings: loaded.standings, favorite: favorite, staleSince: loaded.staleSince)
        return Entry(date: now, content: .standings(model), logo: await logo(favorite), isFresh: isFresh)
    }

    private func logo(_ abbrev: String?) async -> NSImage? {
        guard let abbrev else { return nil }
        return await logoService.image(abbrev)
    }
}
