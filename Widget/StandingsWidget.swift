import SwiftUI
import WidgetKit

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
