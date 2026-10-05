import Foundation

/// Time cached data was saved, shown in the header after a failed fetch.
private func staleTime(_ since: Date?) -> String? {
    since?.formatted(date: .omitted, time: .shortened)
}

struct StandingsViewModel {
    struct Row: Hashable {
        let abbrev: String
        let gamesPlayed: String
        let record: String
        let points: String
        let isFavorite: Bool
    }

    struct Section {
        let title: String
        let rows: [Row]
    }

    let title: String
    let staleLabel: String?
    /// Divisions, then the two wild-card spots.
    let sections: [Section]
    /// Wild-card teams below the playoff line.
    let outside: [Row]

    init(standings: ConferenceStandings, favorite: String?, staleSince: Date?) {
        func rows(_ teams: some Sequence<Team>) -> [Row] {
            teams.map { Row(abbrev: $0.abbrev, gamesPlayed: "\($0.gamesPlayed)", record: $0.record,
                            points: "\($0.points)", isFavorite: $0.abbrev == favorite) }
        }
        title = standings.conference.name
        staleLabel = staleTime(staleSince)
        sections = standings.divisions.map { Section(title: $0.name, rows: rows($0.teams)) }
            + [Section(title: "Wild Card", rows: rows(standings.wildCard.prefix(2)))]
        outside = rows(standings.wildCard.dropFirst(2))
    }
}

struct TeamDetailViewModel {
    struct Stat: Hashable {
        let label: String
        let value: String
    }

    struct Section {
        let title: String
        let stats: [Stat]
    }

    let title: String
    let staleLabel: String?
    let sections: [Section]

    init(team t: Team, staleSince: Date?) {
        title = t.name
        staleLabel = staleTime(staleSince)
        sections = [
            Section(title: "Season", stats: [
                Stat(label: "Record", value: t.record),
                Stat(label: "Points", value: "\(t.points) in \(t.gamesPlayed) GP"),
                Stat(label: "Points %", value: String(format: "%.3f", t.pointPctg)),
            ]),
            Section(title: "Rank", stats: [
                Stat(label: "Division", value: "#\(t.divisionSequence)"),
                Stat(label: "Conference", value: "#\(t.conferenceSequence)"),
                Stat(label: "League", value: "#\(t.leagueSequence)"),
            ]),
            Section(title: "Goals", stats: [
                Stat(label: "For / Against", value: "\(t.goalFor) / \(t.goalAgainst)"),
                Stat(label: "Differential",
                     value: t.goalDifferential.formatted(.number.sign(strategy: .always(includingZero: false)))),
            ]),
            Section(title: "Form", stats: [
                Stat(label: "Home", value: t.homeRecord),
                Stat(label: "Road", value: t.roadRecord),
                Stat(label: "Last 10", value: t.lastTenRecord),
                Stat(label: "Streak", value: t.streak),
            ]),
        ]
    }
}
