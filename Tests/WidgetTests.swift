import SwiftUI
import XCTest

final class WidgetTests: XCTestCase {
    private var saved: [String: Any] = [:]

    override func setUp() {
        StubURLProtocol.install()
        // Intents write UserDefaults.standard; restore it so tests don't leak state.
        saved = UserDefaults.standard.dictionaryRepresentation().filter { ["conference", "selectedTeam"].contains($0.key) }
    }

    override func tearDown() {
        for key in ["conference", "selectedTeam"] { UserDefaults.standard.set(saved[key], forKey: key) }
    }

    func testUserDefaultsWidgetState() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = UserDefaultsWidgetState(defaults: defaults)

        XCTAssertEqual(state.conference, .west)
        XCTAssertNil(state.selectedTeam)
        state.conference = .east
        state.selectedTeam = "BOS"
        XCTAssertEqual(UserDefaultsWidgetState(defaults: defaults).conference, .east)
        XCTAssertEqual(UserDefaultsWidgetState(defaults: defaults).selectedTeam, "BOS")
    }

    func testIntentsUpdateState() async throws {
        let state = UserDefaultsWidgetState()
        state.conference = .west
        state.selectedTeam = nil

        _ = try await SwitchConference().perform()
        XCTAssertEqual(state.conference, .east)
        _ = try await SwitchConference().perform()
        XCTAssertEqual(state.conference, .west)

        _ = try await ShowTeam("COL").perform()
        XCTAssertEqual(state.selectedTeam, "COL")
        _ = try await ShowStandings().perform()
        XCTAssertNil(state.selectedTeam)

        XCTAssertEqual([SwitchConference.title, ShowTeam.title, ShowStandings.title, StandingsConfig.title].map(\.key),
                       ["Switch Conference", "Show Team", "Show Standings", "NHL Standings"])
        _ = ShowTeam()
    }

    @MainActor
    func testViewRendersEveryState() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "fixture", withExtension: "json"))
        let standings = try ConferenceStandings.decode(Data(contentsOf: url), conference: .west)
        let logo = NSImage(size: NSSize(width: 10, height: 10))
        let entries = [
            Entry(date: .now, content: .standings(StandingsViewModel(standings: standings, favorite: "MIN", staleSince: .now)),
                  logo: logo),
            Entry(date: .now, content: .detail(TeamDetailViewModel(team: try XCTUnwrap(standings.team("COL")), staleSince: nil))),
            Entry(date: .now, content: .failed(title: "Western Conference")),
        ]
        for entry in entries {
            let renderer = ImageRenderer(content: StandingsView(entry: entry).frame(width: 330, height: 345))
            XCTAssertNotNil(renderer.nsImage)
        }
    }
}
