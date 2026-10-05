import AppIntents
import Foundation

/// Widget UI state that survives timeline reloads; intents write it, the provider reads it.
enum WidgetState {
    static var conference: Conference {
        get { UserDefaults.standard.string(forKey: "conference").flatMap(Conference.init) ?? .west }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "conference") }
    }

    /// Abbreviation of the team whose detail page is showing, or nil for the standings.
    static var selectedTeam: String? {
        get { UserDefaults.standard.string(forKey: "selectedTeam") }
        set { UserDefaults.standard.set(newValue, forKey: "selectedTeam") }
    }
}

struct SwitchConference: AppIntent {
    static var title: LocalizedStringResource = "Switch Conference"

    func perform() async throws -> some IntentResult {
        WidgetState.conference = WidgetState.conference.toggled
        return .result()
    }
}

struct ShowTeam: AppIntent {
    static var title: LocalizedStringResource = "Show Team"

    @Parameter(title: "Team")
    var abbrev: String

    init() {}
    init(_ abbrev: String) { self.abbrev = abbrev }

    func perform() async throws -> some IntentResult {
        WidgetState.selectedTeam = abbrev
        return .result()
    }
}

struct ShowStandings: AppIntent {
    static var title: LocalizedStringResource = "Show Standings"

    func perform() async throws -> some IntentResult {
        WidgetState.selectedTeam = nil
        return .result()
    }
}

struct StandingsConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "NHL Standings"

    @Parameter(title: "Favorite Team")
    var team: FavoriteTeam?
}
