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
