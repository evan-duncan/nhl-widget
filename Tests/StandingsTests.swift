import XCTest

final class StandingsTests: XCTestCase {
    func testFixtureGroupsWest() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "fixture", withExtension: "json"))
        let s = try WestStandings.decode(Data(contentsOf: url))
        XCTAssertEqual(s.central.map(\.abbrev), ["COL", "MIN", "UTA"])
        XCTAssertEqual(s.pacific.map(\.abbrev), ["EDM", "ANA", "SJS"])
        XCTAssertEqual(s.wildCard.map(\.abbrev), ["SEA", "VGK", "VAN", "WPG", "STL", "NSH", "LAK", "DAL", "CHI", "CGY"])
        XCTAssertEqual(s.pacific.first?.points, 5)
    }

    func testNoWesternTeamsThrows() {
        XCTAssertThrowsError(try WestStandings.decode(Data(#"{"standings":[]}"#.utf8)))
    }

    func testMissingFieldThrows() {
        XCTAssertThrowsError(try WestStandings.decode(Data(#"{"standings":[{"teamAbbrev":{"default":"COL"}}]}"#.utf8)))
    }

    func testSampleShape() {
        let s = WestStandings.sample
        XCTAssertEqual([s.central.count, s.pacific.count, s.wildCard.count], [3, 3, 10])
    }
}
