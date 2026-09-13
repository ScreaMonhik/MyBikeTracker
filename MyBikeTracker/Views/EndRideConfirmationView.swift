import SwiftUI

struct EndRideConfirmationView: View {
    @ObservedObject var viewModel: MapViewModel
    let onConfirm: () -> Void
    let onDiscard: () -> Void
    let onCancel: () -> Void
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            BrandCanvasBackground()

            VStack(spacing: 28) {
                Spacer(minLength: 12)

                Image(systemName: "flag.checkered")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 104, height: 104)
                    .background(Brand.Color.trail.gradient, in: Circle())
                    .shadow(color: Brand.Color.glowTrail, radius: 24, y: 10)
                    .scaleEffect(appeared ? 1 : 0.82)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 8) {
                    Text(LocalizedStringKey("end_ride_title"))
                        .font(Brand.Font.display(28))
                        .foregroundStyle(Brand.Color.ink)
                        .multilineTextAlignment(.center)

                    Text(LocalizedStringKey(viewModel.isRideAccidental ? "end_ride_short_subtitle" : "end_ride_subtitle"))
                        .font(.body)
                        .foregroundStyle(Brand.Color.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    if viewModel.isPaused {
                        BrandBadge(
                            title: LocalizedStringKey("tracking_paused_badge"),
                            kind: .paused
                        )
                        .padding(.top, 4)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                HStack(spacing: 0) {
                    BrandMetric(
                        title: LocalizedStringKey("time_title"),
                        value: viewModel.elapsedTime.formattedAsTimer
                    )
                    metricDivider
                    BrandMetric(
                        title: LocalizedStringKey("distance_title"),
                        value: RideFormatters.distance(meters: viewModel.traveledDistance)
                    )
                    metricDivider
                    BrandMetric(
                        title: LocalizedStringKey("speed_title"),
                        value: RideFormatters.speed(kmh: viewModel.averageSpeed)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .liquidGlass(in: RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous))
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 8)

                VStack(spacing: 12) {
                    GlassActionButton(
                        title: LocalizedStringKey("end_ride_confirm"),
                        systemImage: "checkmark",
                        prominent: !viewModel.isRideAccidental,
                        tint: Brand.Color.danger,
                        action: {
                            BrandHaptics.success()
                            onConfirm()
                        }
                    )

                    GlassActionButton(
                        title: LocalizedStringKey("end_ride_discard"),
                        systemImage: "trash",
                        prominent: viewModel.isRideAccidental,
                        tint: Brand.Color.amber,
                        action: {
                            BrandHaptics.warning()
                            onDiscard()
                        }
                    )

                    GlassActionButton(
                        title: LocalizedStringKey("end_ride_continue"),
                        systemImage: "bicycle",
                        action: onCancel
                    )
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .interactiveDismissDisabled()
        .onAppear {
            withAnimation(Brand.Motion.appear(reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Brand.Color.hairline)
            .frame(width: 1, height: 36)
    }
}
