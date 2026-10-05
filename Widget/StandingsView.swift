import AppIntents
import SwiftUI
import WidgetKit

struct StandingsView: View {
    let entry: Entry

    var body: some View {
        // Logo lives in the content layer, not containerBackground, so it survives glass/tinted modes
        // where the system removes the background.
        // Top-aligned so the header row sits at the same spot on the standings and detail pages.
        content.frame(maxHeight: .infinity, alignment: .top).background {
            if let logo = entry.logo {
                Image(nsImage: logo).resizable().widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit().padding(8).opacity(0.2)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let team = entry.team {
            detail(team)
        } else if let s = entry.standings {
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

    /// Header title plus, when showing cached data after a failed fetch, the time that data was saved.
    private func title(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            if let since = entry.staleSince {
                Label(since.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }
        }
    }

    private var header: some View {
        HStack {
            Button(intent: SwitchConference()) { Image(systemName: "chevron.left") }
            Spacer()
            title(entry.conference.name)
            Spacer()
            Button(intent: SwitchConference()) { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.plain)
        .font(.system(size: 14, weight: .bold))
    }

    private func detail(_ t: Team) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 0) {
            ZStack {
                title(t.name)
                HStack {
                    Button(intent: ShowStandings()) { Image(systemName: "chevron.left") }.buttonStyle(.plain)
                    Spacer()
                }
            }
            .font(.system(size: 14, weight: .bold))
            .padding(.bottom, 6)
            sectionTitle("Season")
            stat("Record", t.record)
            stat("Points", "\(t.points) in \(t.gamesPlayed) GP")
            stat("Points %", String(format: "%.3f", t.pointPctg))
            sectionTitle("Rank")
            stat("Division", "#\(t.divisionSequence)")
            stat("Conference", "#\(t.conferenceSequence)")
            stat("League", "#\(t.leagueSequence)")
            sectionTitle("Goals")
            stat("For / Against", "\(t.goalFor) / \(t.goalAgainst)")
            stat("Differential", t.goalDifferential.formatted(.number.sign(strategy: .always(includingZero: false))))
            sectionTitle("Form")
            stat("Home", t.homeRecord)
            stat("Road", t.roadRecord)
            stat("Last 10", t.lastTenRecord)
            stat("Streak", t.streak)
        }
        .font(.system(size: 11).monospacedDigit())
    }

    private func stat(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).padding(.leading, 6).frame(maxWidth: .infinity, alignment: .leading)
            Text(value).fontWeight(.semibold).gridColumnAlignment(.trailing)
        }
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
            // Favorite team: accent-colored name and bold, full-strength stats.
            let favorite = t.abbrev == entry.favorite
            let stat: HierarchicalShapeStyle = favorite ? .primary : .secondary
            GridRow {
                Button(intent: ShowTeam(t.abbrev)) {
                    Text(t.abbrev).foregroundStyle(favorite ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                }
                .buttonStyle(.plain).padding(.leading, 6)
                Text("\(t.gamesPlayed)").foregroundStyle(stat)
                Text(t.record).foregroundStyle(stat)
                Text("\(t.points)").fontWeight(favorite ? .heavy : .semibold)
            }
            .fontWeight(favorite ? .bold : nil)
        }
    }
}
