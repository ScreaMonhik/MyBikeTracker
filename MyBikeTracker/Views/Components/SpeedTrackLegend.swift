import SwiftUI

/// Compact slow → fast key for the live speed-colored track.
struct SpeedTrackLegend: View {
    var body: some View {
        VStack(spacing: 6) {
            Text(LocalizedStringKey("speed_legend_fast"))
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.muted)

            LinearGradient(
                colors: SpeedHeatmap.legendColors.reversed(),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 8, height: 72)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
            }

            Text(LocalizedStringKey("speed_legend_slow"))
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .liquidGlass(in: RoundedRectangle(cornerRadius: Brand.Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LocalizedStringKey("speed_legend_accessibility"))
    }
}
