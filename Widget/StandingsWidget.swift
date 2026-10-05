import SwiftUI
import WidgetKit

/// WidgetKit glue only: `Context` has no public initializer, so tests call `Provider.timeline(favorite:)` directly.
extension Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry { Self.placeholder }

    func snapshot(for configuration: StandingsConfig, in context: Context) async -> Entry { Self.placeholder }

    func timeline(for configuration: StandingsConfig, in context: Context) async -> Timeline<Entry> {
        await timeline(favorite: configuration.team?.rawValue)
    }
}

@main
struct StandingsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StandingsWidget", intent: StandingsConfig.self, provider: Provider()) { entry in
            StandingsView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("NHL Standings")
        .description("NHL wild-card standings. Tap the arrows to switch conference, or a team for details.")
        .supportedFamilies([.systemLarge])
    }
}
