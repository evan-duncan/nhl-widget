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

    // Detail-page fields. `var` with defaults keeps the sample's memberwise init short; decoding still requires them.
    var teamName = Localized(default: "")
    var pointPctg = 0.0
    var goalFor = 0
    var goalAgainst = 0
    var goalDifferential = 0
    var homeWins = 0, homeLosses = 0, homeOtLosses = 0
    var roadWins = 0, roadLosses = 0, roadOtLosses = 0
    var l10Wins = 0, l10Losses = 0, l10OtLosses = 0
    var streakCode: String? = nil
    var streakCount: Int? = nil
    var conferenceSequence = 0
    var leagueSequence = 0

    var abbrev: String { teamAbbrev.default }
    var name: String { teamName.default }
    var record: String { "\(wins)-\(losses)-\(otLosses)" }
    var homeRecord: String { "\(homeWins)-\(homeLosses)-\(homeOtLosses)" }
    var roadRecord: String { "\(roadWins)-\(roadLosses)-\(roadOtLosses)" }
    var lastTenRecord: String { "\(l10Wins)-\(l10Losses)-\(l10OtLosses)" }
    var streak: String { streakCode.map { "\($0)\(streakCount ?? 0)" } ?? "–" }
}

enum Conference: String {
    case west = "W", east = "E"

    var name: String { self == .west ? "Western Conference" : "Eastern Conference" }
    var toggled: Conference { self == .west ? .east : .west }

    fileprivate var divisions: [(abbrev: String, name: String)] {
        self == .west ? [("C", "Central"), ("P", "Pacific")] : [("A", "Atlantic"), ("M", "Metropolitan")]
    }
}

struct ConferenceStandings {
    struct Division {
        let name: String
        let teams: [Team]
    }

    let conference: Conference
    let divisions: [Division]
    let wildCard: [Team]

    init(teams: [Team], conference: Conference) {
        let mine = teams.filter { $0.conferenceAbbrev == conference.rawValue }
        self.conference = conference
        divisions = conference.divisions.map { division in
            Division(name: division.name,
                     teams: mine.filter { $0.divisionAbbrev == division.abbrev && $0.wildcardSequence == 0 }
                         .sorted { $0.divisionSequence < $1.divisionSequence })
        }
        wildCard = mine.filter { $0.wildcardSequence > 0 }.sorted { $0.wildcardSequence < $1.wildcardSequence }
    }

    func team(_ abbrev: String) -> Team? {
        (divisions.flatMap(\.teams) + wildCard).first { $0.abbrev == abbrev }
    }

    static let sample: ConferenceStandings = {
        let rows = [("COL", "C", 0), ("MIN", "C", 0), ("UTA", "C", 0), ("EDM", "P", 0), ("ANA", "P", 0), ("SJS", "P", 0),
                    ("SEA", "P", 1), ("VGK", "P", 2), ("VAN", "P", 3), ("WPG", "C", 4), ("STL", "C", 5),
                    ("NSH", "C", 6), ("LAK", "P", 7), ("DAL", "C", 8), ("CHI", "C", 9), ("CGY", "P", 10)]
        return ConferenceStandings(teams: rows.enumerated().map { i, row in
            Team(teamAbbrev: .init(default: row.0), conferenceAbbrev: "W", divisionAbbrev: row.1, divisionSequence: i,
                 wildcardSequence: row.2, gamesPlayed: 0, wins: 0, losses: 0, otLosses: 0, points: 0)
        }, conference: .west)
    }()
}
