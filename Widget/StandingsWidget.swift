import AppIntents
import SwiftUI
import WidgetKit

struct SwitchConference: AppIntent {
    static var title: LocalizedStringResource = "Switch Conference"

    func perform() async throws -> some IntentResult {
        Conference.current = Conference.current.toggled
        return .result()
    }
}

struct StandingsConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "NHL Standings"

    @Parameter(title: "Favorite Team")
    var team: FavoriteTeam?
}

struct Entry: TimelineEntry {
    let date: Date
    let conference: Conference
    let standings: ConferenceStandings?
    var logo: NSImage? = nil
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, conference: .west, standings: .sample) }

    func snapshot(for configuration: StandingsConfig, in context: Context) async -> Entry {
        placeholder(in: context)
    }

    func timeline(for configuration: StandingsConfig, in context: Context) async -> Timeline<Entry> {
        let conference = Conference.current
        let standings = try? await ConferenceStandings.fetch(conference)
        var logo: NSImage?
        if let team = configuration.team, let (data, _) = try? await URLSession.shared.data(from: team.logoURL) {
            logo = NSImage(data: data)
        }
        let minutes: Double = standings == nil ? 15 : 30
        return Timeline(entries: [Entry(date: .now, conference: conference, standings: standings, logo: logo)],
                        policy: .after(.now.addingTimeInterval(minutes * 60)))
    }
}

struct StandingsView: View {
    let entry: Entry

    var body: some View {
        // Logo lives in the content layer, not containerBackground, so it survives glass/tinted modes
        // where the system removes the background.
        content.background {
            if let logo = entry.logo {
                Image(nsImage: logo).resizable().widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit().padding(8).opacity(0.2)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let s = entry.standings {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 0) {
                header.padding(.bottom, 6)
                GridRow(alignment: .lastTextBaseline) {
                    sectionTitle(s.divisions[0].name).frame(maxWidth: .infinity, alignment: .leading)
                    Group {
                        Text("GP").gridColumnAlignment(.trailing)
                        Text("W-L-OT").gridColumnAlignment(.trailing)
                        Text("PTS").gridColumnAlignment(.trailing)
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
                rows(s.divisions[0].teams)
                ForEach(s.divisions.dropFirst(), id: \.name) { section($0.name, $0.teams) }
                section("Wild Card", Array(s.wildCard.prefix(2)))
                Rectangle().fill(.secondary).frame(height: 2).padding(.vertical, 1)
                rows(Array(s.wildCard.dropFirst(2)))
            }
            .font(.system(size: 11).monospacedDigit())
        } else {
            VStack(alignment: .leading) {
                header
                Spacer()
                Text("Couldn't load standings").foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }

    private var header: some View {
        HStack {
            Button(intent: SwitchConference()) { Image(systemName: "chevron.left") }
            Spacer()
            Text(entry.conference.name)
            Spacer()
            Button(intent: SwitchConference()) { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.plain)
        .font(.system(size: 14, weight: .bold))
    }

    @ViewBuilder
    private func section(_ title: String, _ teams: [Team]) -> some View {
        sectionTitle(title)
        rows(teams)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 12, weight: .bold)).padding(.top, 3)
    }

    private func rows(_ teams: [Team]) -> some View {
        ForEach(teams, id: \.abbrev) { t in
            GridRow {
                Text(t.abbrev).padding(.leading, 6)
                Text("\(t.gamesPlayed)").foregroundStyle(.secondary)
                Text("\(t.wins)-\(t.losses)-\(t.otLosses)").foregroundStyle(.secondary)
                Text("\(t.points)").fontWeight(.semibold)
            }
        }
    }
}

@main
struct StandingsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StandingsWidget", intent: StandingsConfig.self, provider: Provider()) { entry in
            StandingsView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("NHL Standings")
        .description("NHL wild-card standings. Tap the arrows to switch conference.")
        .supportedFamilies([.systemLarge])
    }
}
