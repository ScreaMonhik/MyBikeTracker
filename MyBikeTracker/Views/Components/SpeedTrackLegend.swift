import SwiftUI

/// Compact slow → fast key for the live speed-colored track.
struct SpeedTrackLegend: View {
    var body: some View {
        VStack(spacing: 6) {
            Text(LocalizedStringKey("speed_legend_fast"))
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.ink)

            LinearGradient(
                colors: SpeedHeatmap.legendColors.reversed(),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 8, height: 72)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            }

            Text(LocalizedStringKey("speed_legend_slow"))
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .liquidGlass(in: RoundedRectangle(cornerRadius: Brand.Radius.sm, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LocalizedStringKey("speed_legend_accessibility"))
    }
}
