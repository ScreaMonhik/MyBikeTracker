import SwiftUI

extension AppTab {
    var title: LocalizedStringKey {
        switch self {
        case .map: LocalizedStringKey("map_tab_title")
        case .trip: LocalizedStringKey("trip_tab_title")
        case .history: LocalizedStringKey("history_tab_title")
        case .settings: LocalizedStringKey("settings_tab_title")
        }
    }

    var icon: String {
        switch self {
        case .map: "map"
        case .trip: "figure.outdoor.cycle"
        case .history: "clock"
        case .settings: "slider.horizontal.3"
        }
    }

    var selectedIcon: String {
        switch self {
        case .map: "map.fill"
        case .trip: "figure.outdoor.cycle"
        case .history: "clock.fill"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct BrandTabBar: View {
    /// Space each tab must keep clear so controls do not sit under the bar.
    static let contentClearance: CGFloat = 88

    @Binding var selection: AppTab
    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.14), radius: 22, y: 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            BrandHaptics.select()
            withAnimation(Brand.Motion.snappy(reduceMotion: reduceMotion)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                    .foregroundStyle(isSelected ? Brand.Color.trail : Brand.Color.muted)
                    .frame(height: 24)
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Brand.Color.trail : Brand.Color.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Brand.Color.trail.opacity(0.16))
                        .matchedGeometryEffect(id: "tab-pill", in: tabNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
