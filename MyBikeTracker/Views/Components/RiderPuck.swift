import SwiftUI

/// Branded cyclist marker that sits on the live track tip.
struct RiderPuck: View {
    var heading: Angle?
    var isLive: Bool
    var accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isLive {
                Circle()
                    .fill(accent.opacity(reduceMotion ? 0.16 : 0.22))
                    .frame(width: 54, height: 54)
                    .scaleEffect(reduceMotion ? 1 : 1.08)
            }

            Circle()
                .fill(Color.white)
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.22), radius: 8, y: 3)

            Circle()
                .fill(accent.gradient)
                .frame(width: 32, height: 32)

            Image(systemName: "figure.outdoor.cycle")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 56, height: 56)
        .overlay {
            if let heading {
                RiderHeadingChevron()
                    .fill(accent)
                    .frame(width: 12, height: 8)
                    .offset(y: -24)
                    .frame(width: 56, height: 56)
                    .rotationEffect(heading)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct RiderHeadingChevron: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
