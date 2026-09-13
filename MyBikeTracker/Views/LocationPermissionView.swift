import SwiftUI
import CoreLocation

struct LocationPermissionView: View {
    @ObservedObject var locationService: LocationService

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(Brand.Color.ember)
                .accessibilityHidden(true)

            Text(LocalizedStringKey("location_needed_title"))
                .font(Brand.Font.headline)
                .foregroundStyle(Brand.Color.ink)
                .multilineTextAlignment(.center)

            Text(LocalizedStringKey(locationService.isDenied ? "location_denied_body" : "location_needed_body"))
                .font(Brand.Font.body)
                .foregroundStyle(Brand.Color.muted)
                .multilineTextAlignment(.center)

            GlassActionButton(
                title: LocalizedStringKey(locationService.isDenied ? "location_open_settings" : "location_allow_button"),
                systemImage: "location.fill",
                prominent: true,
                tint: Brand.Color.trail
            ) {
                if locationService.isDenied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    locationService.requestWhenInUse()
                }
            }
        }
        .padding(20)
        .liquidGlass(in: RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }
}
