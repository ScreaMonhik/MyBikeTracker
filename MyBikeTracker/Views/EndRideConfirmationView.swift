import SwiftUI

struct EndRideConfirmationView: View {
    @ObservedObject var viewModel: MapViewModel
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 12)

                Image(systemName: "flag.checkered")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(28)
                    .liquidGlass(in: Circle())

                VStack(spacing: 8) {
                    Text(LocalizedStringKey("end_ride_title"))
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(LocalizedStringKey("end_ride_subtitle"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    if viewModel.isPaused {
                        Text(LocalizedStringKey("tracking_paused_badge"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange.opacity(0.22)))
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                    }
                }

                HStack(spacing: 0) {
                    metricBox(
                        title: LocalizedStringKey("time_title"),
                        value: viewModel.elapsedTime.formattedAsTimer
                    )
                    metricDivider
                    metricBox(
                        title: LocalizedStringKey("distance_title"),
                        value: RideFormatters.distance(meters: viewModel.traveledDistance)
                    )
                    metricDivider
                    metricBox(
                        title: LocalizedStringKey("speed_title"),
                        value: RideFormatters.speed(kmh: viewModel.averageSpeed)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Spacer(minLength: 8)

                VStack(spacing: 12) {
                    GlassActionButton(
                        title: LocalizedStringKey("end_ride_confirm"),
                        systemImage: "checkmark",
                        prominent: true,
                        tint: .red,
                        action: onConfirm
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
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.12))
            .frame(width: 1, height: 36)
    }

    private func metricBox(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}
