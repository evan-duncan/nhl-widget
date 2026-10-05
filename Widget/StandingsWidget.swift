import SwiftUI
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let standings: WestStandings?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, standings: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let standings = try? await WestStandings.fetch()
            let minutes: Double = standings == nil ? 15 : 30
            completion(Timeline(entries: [Entry(date: .now, standings: standings)],
                                policy: .after(.now.addingTimeInterval(minutes * 60))))
        }
    }
}

struct StandingsView: View {
    let entry: Entry

    var body: some View {
        if let s = entry.standings {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 0) {
                GridRow(alignment: .lastTextBaseline) {
                    Text("Western Conference").font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Group {
                        Text("GP").gridColumnAlignment(.trailing)
                        Text("W-L-OT").gridColumnAlignment(.trailing)
                        Text("PTS").gridColumnAlignment(.trailing)
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
                section("Central", s.central)
                section("Pacific", s.pacific)
                section("Wild Card", Array(s.wildCard.prefix(2)))
                Divider()
                rows(Array(s.wildCard.dropFirst(2)))
            }
            .font(.system(size: 11).monospacedDigit())
        } else {
            Text("Couldn't load standings").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ teams: [Team]) -> some View {
        Text(title).font(.system(size: 12, weight: .bold)).padding(.top, 3)
        rows(teams)
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
        StaticConfiguration(kind: "StandingsWidget", provider: Provider()) { entry in
            StandingsView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("West Standings")
        .description("NHL Western Conference wild-card standings.")
        .supportedFamilies([.systemLarge])
    }
}
