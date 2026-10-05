import XCTest

final class StandingsTests: XCTestCase {
    override func setUp() { StubURLProtocol.install() }

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
        XCTAssertEqual(NHLLogoService.url("COL").absoluteString, "https://assets.nhle.com/logos/nhl/svg/COL_light.svg")
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

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    private let svg = Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>"#.utf8)

    func testLogoReadsFromCacheWithoutNetwork() async throws {
        let dir = try tempDir()
        try svg.write(to: dir.appendingPathComponent("ZZZ.svg"))
        let requests = StubURLProtocol.respond(500)
        let image = await NHLLogoService(cacheDir: dir, session: StubURLProtocol.session).image("ZZZ")
        XCTAssertEqual(image?.size, NSSize(width: 10, height: 10))
        XCTAssertEqual(requests(), [])
    }

    func testLogoDownloadsAndCaches() async throws {
        let dir = try tempDir()
        let requests = StubURLProtocol.respond(200, svg)
        let image = await NHLLogoService(cacheDir: dir, session: StubURLProtocol.session).image("COL")
        XCTAssertEqual(image?.size, NSSize(width: 10, height: 10))
        XCTAssertEqual(requests(), [NHLLogoService.url("COL")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("COL.svg").path))
    }

    func testLogoFailureReturnsNil() async throws {
        let dir = try tempDir()
        _ = StubURLProtocol.respond(404)
        let missing = await NHLLogoService(cacheDir: dir, session: StubURLProtocol.session).image("COL")
        XCTAssertNil(missing)
        StubURLProtocol.handler = StubURLProtocol.unstubbed
        let offline = await NHLLogoService(cacheDir: dir, session: StubURLProtocol.session).image("COL")
        XCTAssertNil(offline)
    }

    func testLoadCachesAndFallsBack() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "fixture", withExtension: "json"))
        let fixtureData = try Data(contentsOf: url)
        let service = NHLStandingsService(cacheFile: try tempDir().appendingPathComponent("standings.json"),
                                          session: StubURLProtocol.session)

        let requests = StubURLProtocol.respond(200, fixtureData)
        let freshResult = await service.load(.west)
        let fresh = try XCTUnwrap(freshResult)
        XCTAssertNil(fresh.staleSince)
        XCTAssertEqual(requests().map(\.absoluteString), ["https://api-web.nhle.com/v1/standings/now"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.cacheFile.path))

        _ = StubURLProtocol.respond(503)
        let staleResult = await service.load(.west)
        let stale = try XCTUnwrap(staleResult)
        XCTAssertNotNil(stale.staleSince)
        XCTAssertEqual(stale.standings.divisions[0].teams.map(\.abbrev), ["COL", "MIN", "UTA"])

        _ = StubURLProtocol.respond(200, Data("<html>".utf8))
        let badResult = await service.load(.west)
        XCTAssertNotNil(try XCTUnwrap(badResult).staleSince)

        try FileManager.default.removeItem(at: service.cacheFile)
        StubURLProtocol.handler = StubURLProtocol.unstubbed
        let none = await service.load(.west)
        XCTAssertNil(none)
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
