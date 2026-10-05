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
