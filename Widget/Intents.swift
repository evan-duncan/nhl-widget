import AppIntents
import Foundation

/// Widget UI state that survives timeline reloads; intents write it, the provider reads it.
protocol WidgetStateStore {
    var conference: Conference { get nonmutating set }
    /// Abbreviation of the team whose detail page is showing, or nil for the standings.
    var selectedTeam: String? { get nonmutating set }
}

struct UserDefaultsWidgetState: WidgetStateStore {
    var defaults = UserDefaults.standard

    var conference: Conference {
        get { defaults.string(forKey: "conference").flatMap(Conference.init) ?? .west }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "conference") }
    }

    var selectedTeam: String? {
        get { defaults.string(forKey: "selectedTeam") }
        nonmutating set { defaults.set(newValue, forKey: "selectedTeam") }
    }
}

struct SwitchConference: AppIntent {
    static var title: LocalizedStringResource = "Switch Conference"

    func perform() async throws -> some IntentResult {
        let state = UserDefaultsWidgetState()
        state.conference = state.conference.toggled
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
        UserDefaultsWidgetState().selectedTeam = abbrev
        return .result()
    }
}

struct ShowStandings: AppIntent {
    static var title: LocalizedStringResource = "Show Standings"

    func perform() async throws -> some IntentResult {
        UserDefaultsWidgetState().selectedTeam = nil
        return .result()
    }
}

struct StandingsConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "NHL Standings"

    @Parameter(title: "Favorite Team")
    var team: FavoriteTeam?
}
