import SwiftUI

struct BrandCanvasBackground: View {
    var body: some View {
        ZStack {
            Brand.Color.canvas
            RadialGradient(
                colors: [Brand.Color.trail.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )
            RadialGradient(
                colors: [Brand.Color.ember.opacity(0.10), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 280
            )
        }
        .ignoresSafeArea()
    }
}

struct BrandCard<Content: View>: View {
    var padding: CGFloat = Brand.Space.md
    var fill: Color = Brand.Color.surface
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous)
                    .strokeBorder(Brand.Color.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
    }
}

struct BrandMetric: View {
    let title: LocalizedStringKey
    let value: String
    var size: CGFloat = 20
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.muted)
                .lineLimit(1)
            Text(value)
                .font(Brand.Font.metric(size))
                .foregroundStyle(Brand.Color.ink)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
        .accessibilityElement(children: .combine)
    }
}

struct BrandBadge: View {
    enum Kind {
        case live, paused, warning, info, custom(Color)

        var color: Color {
            switch self {
            case .live: Brand.Color.live
            case .paused: Brand.Color.paused
            case .warning: Brand.Color.amber
            case .info: Brand.Color.trail
            case .custom(let color): color
            }
        }
    }

    let title: LocalizedStringKey
    var kind: Kind = .info
    var showsPulse: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if showsPulse {
                LivePulseDot(color: kind.color)
            }
            Text(title)
                .font(Brand.Font.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(kind.color)
        .background(kind.color.opacity(0.16), in: Capsule())
    }
}

struct LivePulseDot: View {
    var color: Color = Brand.Color.live
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 0.7, paused: reduceMotion)) { context in
            let pulse = reduceMotion ? 1.0 : (sin(context.date.timeIntervalSinceReferenceDate * 3.2) + 1) / 2
            ZStack {
                Circle()
                    .fill(color.opacity(0.28))
                    .scaleEffect(1.15 + (0.55 * pulse))
                Circle()
                    .fill(color)
            }
            .frame(width: 8, height: 8)
        }
    }
}

struct BrandEmptyState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var systemImage: String = "bicycle"

    var body: some View {
        VStack(spacing: Brand.Space.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(Brand.Color.trail)
                .frame(width: 72, height: 72)
                .background(Brand.Color.trail.opacity(0.12), in: Circle())
            Text(title)
                .font(Brand.Font.headline)
                .foregroundStyle(Brand.Color.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Brand.Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Brand.Space.xl)
    }
}

struct BrandFloatingChip: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
            }
            Text(title)
                .font(Brand.Font.headline)
        }
        .foregroundStyle(Brand.Color.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlass(in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

struct BrandCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(Brand.Motion.snappy, value: configuration.isPressed)
    }
}

struct BrandSectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(Brand.Font.headline)
            .foregroundStyle(Brand.Color.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func brandScreen() -> some View {
        background { BrandCanvasBackground() }
            .tint(Brand.Color.trail)
    }

    func brandListChrome() -> some View {
        scrollContentBackground(.hidden)
            .background { BrandCanvasBackground() }
            .tint(Brand.Color.trail)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .contentMargins(.bottom, BrandTabBar.contentClearance, for: .scrollContent)
    }

    func brandListGutter() -> some View {
        contentMargins(.horizontal, Brand.Space.lg, for: .scrollContent)
    }

    func hidesSystemTabBar() -> some View {
        toolbar(.hidden, for: .tabBar)
    }

    func brandTabBarClearance() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: BrandTabBar.contentClearance)
        }
    }

    func brandAppear(_ isVisible: Bool, reduceMotion: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .animation(Brand.Motion.appear(reduceMotion: reduceMotion), value: isVisible)
    }

    func brandListCard(fill: Color = Brand.Color.surface) -> some View {
        background {
            RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous)
                .fill(fill)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
