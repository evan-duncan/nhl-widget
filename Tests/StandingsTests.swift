import XCTest

final class StandingsTests: XCTestCase {
    private func fixture(_ conference: Conference) throws -> ConferenceStandings {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "fixture", withExtension: "json"))
        return try ConferenceStandings.decode(Data(contentsOf: url), conference: conference)
    }

    func testFixtureGroupsWest() throws {
        let s = try fixture(.west)
        XCTAssertEqual(s.divisions.map(\.name), ["Central", "Pacific"])
        XCTAssertEqual(s.divisions.map { $0.teams.map(\.abbrev) }, [["COL", "MIN", "UTA"], ["EDM", "ANA", "SJS"]])
        XCTAssertEqual(s.wildCard.map(\.abbrev), ["SEA", "VGK", "VAN", "WPG", "STL", "NSH", "LAK", "DAL", "CHI", "CGY"])
        XCTAssertEqual(s.divisions[1].teams.first?.points, 5)
    }

    func testFixtureGroupsEast() throws {
        let s = try fixture(.east)
        XCTAssertEqual(s.divisions.map(\.name), ["Atlantic", "Metropolitan"])
        XCTAssertEqual(s.divisions.map { $0.teams.map(\.abbrev) }, [["BOS", "FLA", "MTL"], ["NYR", "PIT", "CAR"]])
        XCTAssertEqual(s.wildCard.map(\.abbrev), ["OTT", "NYI", "WSH", "CBJ", "BUF", "TBL", "NJD", "TOR", "PHI", "DET"])
    }

    func testFavoriteTeamsMatchLeague() throws {
        struct Response: Decodable { let standings: [Team] }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "fixture", withExtension: "json"))
        let league = try JSONDecoder().decode(Response.self, from: Data(contentsOf: url)).standings.map(\.abbrev)
        XCTAssertEqual(Set(FavoriteTeam.allCases.map(\.rawValue)), Set(league))
        XCTAssertEqual(Logos.url("COL").absoluteString, "https://assets.nhle.com/logos/nhl/svg/COL_light.svg")
    }

    func testTeamDetails() throws {
        let s = try fixture(.west)
        let col = try XCTUnwrap(s.team("COL"))
        XCTAssertEqual(col.name, "Colorado Avalanche")
        XCTAssertEqual(col.record, "2-0-0")
        XCTAssertEqual(col.homeRecord, "2-0-0")
        XCTAssertEqual(col.roadRecord, "0-0-0")
        XCTAssertEqual(col.lastTenRecord, "2-0-0")
        XCTAssertEqual(col.streak, "W2")
        XCTAssertEqual([col.goalFor, col.goalAgainst, col.goalDifferential], [14, 5, 9])
        XCTAssertEqual([col.divisionSequence, col.conferenceSequence, col.leagueSequence], [1, 2, 3])
        XCTAssertEqual(try XCTUnwrap(s.team("SEA")).abbrev, "SEA")
        XCTAssertNil(s.team("BOS"))
    }

    func testLogoReadsFromCacheWithoutNetwork() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>"#
        try Data(svg.utf8).write(to: dir.appendingPathComponent("ZZZ.svg"))
        let image = await Logos.image("ZZZ", cacheDir: dir)
        XCTAssertEqual(image?.size, NSSize(width: 10, height: 10))
    }

    func testToggled() {
        XCTAssertEqual(Conference.west.toggled, .east)
        XCTAssertEqual(Conference.east.toggled, .west)
    }

    func testNoTeamsThrows() {
        XCTAssertThrowsError(try ConferenceStandings.decode(Data(#"{"standings":[]}"#.utf8), conference: .west))
    }

    func testMissingFieldThrows() {
        XCTAssertThrowsError(try ConferenceStandings.decode(Data(#"{"standings":[{"teamAbbrev":{"default":"COL"}}]}"#.utf8), conference: .west))
    }

    func testSampleShape() {
        let s = ConferenceStandings.sample
        XCTAssertEqual(s.divisions.map(\.teams.count) + [s.wildCard.count], [3, 3, 10])
    }
}
