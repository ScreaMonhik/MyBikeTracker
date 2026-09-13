import SwiftUI
import UIKit

/// Blur fallback for iOS versions that do not have Liquid Glass.
struct ChromeGlass: UIViewRepresentable {
    var cornerRadius: CGFloat

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.layer.cornerRadius = cornerRadius
    }
}

extension View {
    /// Liquid Glass on iOS 26+, chrome material on earlier versions.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self
                .background {
                    ChromeGlass(cornerRadius: Self.fallbackRadius(for: shape))
                }
                .clipShape(shape)
        }
    }

    /// Groups sibling glass surfaces so they can morph and share lighting on iOS 26.
    @ViewBuilder
    func liquidGlassContainer<Content: View>(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }

    @ViewBuilder
    func liquidGlassButtonStyle(prominent: Bool = false, circular: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(circular ? .circle : .capsule)
            } else {
                self
                    .buttonStyle(.glass)
                    .buttonBorderShape(circular ? .circle : .capsule)
            }
        } else {
            self.buttonStyle(.plain)
        }
    }

    private static func fallbackRadius<S: Shape>(for shape: S) -> CGFloat {
        if let capsule = shape as? Capsule {
            _ = capsule
            return 24
        }
        if let circle = shape as? Circle {
            _ = circle
            return 25
        }
        return 20
    }
}

/// Circular map-tool button (search, locate, clear route).
struct GlassMapButton: View {
    let systemImage: String
    let accessibilityKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button {
            BrandHaptics.light()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Brand.Color.ink)
                .frame(width: 50, height: 50)
                .legacyGlassChrome(cornerRadius: 25, shape: Circle())
        }
        .liquidGlassButtonStyle(circular: true)
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        .accessibilityLabel(accessibilityKey)
    }
}

/// Capsule control used for Start / Pause / Stop.
struct GlassActionButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var prominent: Bool = false
    var tint: Color? = nil
    let action: () -> Void

    private var accent: Color { tint ?? Brand.Color.trail }

    var body: some View {
        Button {
            if prominent {
                BrandHaptics.medium()
            } else {
                BrandHaptics.light()
            }
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(Brand.Font.headline)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .frame(minWidth: 132)
                .foregroundStyle(prominent ? Color.white : Brand.Color.ink)
                .background {
                    if prominent {
                        Capsule()
                            .fill(accent.gradient)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                }
                .overlay {
                    Capsule()
                        .strokeBorder(prominent ? Color.white.opacity(0.18) : Brand.Color.hairline, lineWidth: 1)
                }
                .shadow(color: prominent ? accent.opacity(0.35) : .black.opacity(0.08), radius: prominent ? 16 : 8, y: 6)
        }
        .buttonStyle(.plain)
        .tint(accent)
    }
}

private extension View {
    /// Material chrome used only before Liquid Glass exists. On iOS 26 the
    /// system button style already draws the glass surface.
    @ViewBuilder
    func legacyGlassChrome<S: InsettableShape>(
        cornerRadius: CGFloat,
        shape: S,
        enabled: Bool = true
    ) -> some View {
        if !enabled {
            self
        } else if #available(iOS 26.0, *) {
            self
        } else {
            self
                .background {
                    ChromeGlass(cornerRadius: cornerRadius)
                }
                .clipShape(shape)
                .overlay(shape.strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
        }
    }
}
