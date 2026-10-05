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

enum Conference: String {
    case west = "W", east = "E"

    var name: String { self == .west ? "Western Conference" : "Eastern Conference" }
    var toggled: Conference { self == .west ? .east : .west }

    fileprivate var divisions: [(abbrev: String, name: String)] {
        self == .west ? [("C", "Central"), ("P", "Pacific")] : [("A", "Atlantic"), ("M", "Metropolitan")]
    }

    static var current: Conference {
        get { UserDefaults.standard.string(forKey: "conference").flatMap(Conference.init) ?? .west }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "conference") }
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

    static func decode(_ data: Data, conference: Conference) throws -> ConferenceStandings {
        struct Response: Decodable { let standings: [Team] }
        let standings = ConferenceStandings(teams: try JSONDecoder().decode(Response.self, from: data).standings, conference: conference)
        guard standings.divisions.contains(where: { !$0.teams.isEmpty }) else { throw URLError(.cannotParseResponse) }
        return standings
    }

    static func fetch(_ conference: Conference) async throws -> ConferenceStandings {
        let (data, response) = try await URLSession.shared.data(from: URL(string: "https://api-web.nhle.com/v1/standings/now")!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decode(data, conference: conference)
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
