import XCTest

private struct FakeStandings: StandingsService {
    var result: (standings: ConferenceStandings, staleSince: Date?)?
    func load(_ conference: Conference) async -> (standings: ConferenceStandings, staleSince: Date?)? { result }
}

private struct FakeLogos: LogoService {
    func image(_ abbrev: String) async -> NSImage? {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.setName(abbrev)
        return image
    }
}

private final class FakeState: WidgetStateStore {
    var conference = Conference.west
    var selectedTeam: String?
}

final class ViewModelTests: XCTestCase {
    private func fixture() throws -> ConferenceStandings {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "fixture", withExtension: "json"))
        return try ConferenceStandings.decode(Data(contentsOf: url), conference: .west)
    }

    func testStandingsViewModel() throws {
        let model = StandingsViewModel(standings: try fixture(), favorite: "MIN", staleSince: nil)
        XCTAssertEqual(model.title, "Western Conference")
        XCTAssertNil(model.staleLabel)
        XCTAssertEqual(model.sections.map(\.title), ["Central", "Pacific", "Wild Card"])
        XCTAssertEqual(model.sections[2].rows.map(\.abbrev), ["SEA", "VGK"])
        XCTAssertEqual(model.outside.count, 8)
        XCTAssertEqual(model.sections[0].rows[0],
                       .init(abbrev: "COL", gamesPlayed: "2", record: "2-0-0", points: "4", isFavorite: false))
        XCTAssertEqual(model.sections.flatMap(\.rows).filter(\.isFavorite).map(\.abbrev), ["MIN"])
    }

    func testDetailViewModel() throws {
        let model = TeamDetailViewModel(team: try XCTUnwrap(fixture().team("COL")), staleSince: .now)
        XCTAssertEqual(model.title, "Colorado Avalanche")
        XCTAssertNotNil(model.staleLabel)
        XCTAssertEqual(model.sections.map(\.title), ["Season", "Rank", "Goals", "Form"])
        XCTAssertEqual(model.sections[0].stats.map(\.value), ["2-0-0", "4 in 2 GP", "1.000"])
        XCTAssertEqual(model.sections[2].stats.map(\.value), ["14 / 5", "+9"])
        XCTAssertEqual(model.sections[3].stats.last, .init(label: "Streak", value: "W2"))
    }

    func testProviderShowsStandingsWithFavoriteLogo() async throws {
        let provider = Provider(standingsService: FakeStandings(result: (try fixture(), nil)),
                                logoService: FakeLogos(), state: FakeState())
        let entry = await provider.entry(favorite: "MIN")
        guard case .standings = entry.content else { return XCTFail("expected standings") }
        XCTAssertEqual(entry.logo?.name(), "MIN")
        XCTAssertTrue(entry.isFresh)
    }

    func testProviderShowsSelectedTeamDetail() async throws {
        let state = FakeState()
        state.selectedTeam = "COL"
        let provider = Provider(standingsService: FakeStandings(result: (try fixture(), .distantPast)),
                                logoService: FakeLogos(), state: state)
        let entry = await provider.entry(favorite: "MIN")
        guard case .detail(let model) = entry.content else { return XCTFail("expected detail") }
        XCTAssertEqual(model.title, "Colorado Avalanche")
        XCTAssertEqual(entry.logo?.name(), "COL")
        XCTAssertFalse(entry.isFresh)
    }

    func testProviderFailsWithoutData() async {
        let state = FakeState()
        state.conference = .east
        let provider = Provider(standingsService: FakeStandings(result: nil), logoService: FakeLogos(), state: state)
        let entry = await provider.entry(favorite: nil)
        guard case .failed(let title) = entry.content else { return XCTFail("expected failure") }
        XCTAssertEqual(title, "Eastern Conference")
        XCTAssertNil(entry.logo)
        XCTAssertFalse(entry.isFresh)
    }
}
