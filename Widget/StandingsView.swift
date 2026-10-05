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
        switch entry.content {
        case .detail(let model):
            detail(model)
        case .standings(let model):
            standings(model)
        case .failed(let title):
            VStack(alignment: .leading) {
                header(title, staleLabel: nil)
                Spacer()
                Text("Couldn't load standings").foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }

    private func standings(_ model: StandingsViewModel) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 0) {
            header(model.title, staleLabel: model.staleLabel).padding(.bottom, 6)
            GridRow(alignment: .lastTextBaseline) {
                sectionTitle(model.sections[0].title).frame(maxWidth: .infinity, alignment: .leading)
                Group {
                    Text("GP").gridColumnAlignment(.trailing)
                    Text("W-L-OT").gridColumnAlignment(.trailing)
                    Text("PTS").gridColumnAlignment(.trailing)
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            }
            rows(model.sections[0].rows)
            ForEach(model.sections.dropFirst(), id: \.title) { section in
                sectionTitle(section.title)
                rows(section.rows)
            }
            Rectangle().fill(.secondary).frame(height: 2).padding(.vertical, 1)
            rows(model.outside)
        }
        .font(.system(size: 11).monospacedDigit())
    }

    /// Header title plus, when showing cached data after a failed fetch, the time that data was saved.
    private func title(_ text: String, staleLabel: String?) -> some View {
        HStack(spacing: 4) {
            Text(text)
            if let staleLabel {
                Label(staleLabel, systemImage: "clock")
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }
        }
    }

    private func header(_ text: String, staleLabel: String?) -> some View {
        HStack {
            Button(intent: SwitchConference()) { Image(systemName: "chevron.left") }
            Spacer()
            title(text, staleLabel: staleLabel)
            Spacer()
            Button(intent: SwitchConference()) { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.plain)
        .font(.system(size: 14, weight: .bold))
    }

    private func detail(_ model: TeamDetailViewModel) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 0) {
            ZStack {
                title(model.title, staleLabel: model.staleLabel)
                HStack {
                    Button(intent: ShowStandings()) { Image(systemName: "chevron.left") }.buttonStyle(.plain)
                    Spacer()
                }
            }
            .font(.system(size: 14, weight: .bold))
            .padding(.bottom, 6)
            ForEach(model.sections, id: \.title) { section in
                sectionTitle(section.title)
                ForEach(section.stats, id: \.label) { stat in
                    GridRow {
                        Text(stat.label).foregroundStyle(.secondary).padding(.leading, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(stat.value).fontWeight(.semibold).gridColumnAlignment(.trailing)
                    }
                }
            }
        }
        .font(.system(size: 11).monospacedDigit())
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 12, weight: .bold)).padding(.top, 3)
    }

    private func rows(_ rows: [StandingsViewModel.Row]) -> some View {
        ForEach(rows, id: \.abbrev) { row in
            // Favorite team: accent-colored name and bold, full-strength stats.
            let stat: HierarchicalShapeStyle = row.isFavorite ? .primary : .secondary
            GridRow {
                Button(intent: ShowTeam(row.abbrev)) {
                    Text(row.abbrev).foregroundStyle(row.isFavorite ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                }
                .buttonStyle(.plain).padding(.leading, 6)
                Text(row.gamesPlayed).foregroundStyle(stat)
                Text(row.record).foregroundStyle(stat)
                Text(row.points).fontWeight(row.isFavorite ? .heavy : .semibold)
            }
            .fontWeight(row.isFavorite ? .bold : nil)
        }
    }
}
