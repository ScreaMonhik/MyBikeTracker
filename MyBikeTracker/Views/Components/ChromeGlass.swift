import SwiftUI
import UIKit

struct ChromeGlass: UIViewRepresentable {
    var cornerRadius: CGFloat

    func makeUIView(context: Context) -> UIVisualEffectView {
        let effect = UIBlurEffect(style: .systemChromeMaterial)
        let view = UIVisualEffectView(effect: effect)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.layer.cornerRadius = cornerRadius
    }
}
