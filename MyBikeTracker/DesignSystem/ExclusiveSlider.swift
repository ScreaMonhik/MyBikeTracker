import SwiftUI
import UIKit

/// `UISlider` that keeps the drag even while a parent `Form` / `List` shows its scroll indicator.
struct ExclusiveSlider: UIViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var accent: UIColor = UIColor(Brand.Color.trail)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(value)
        slider.isExclusiveTouch = true
        slider.minimumTrackTintColor = accent
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.parent = self
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.minimumTrackTintColor = accent
        let stepped = steppedValue(value)
        if !slider.isTracking, abs(Double(slider.value) - stepped) > step / 4 {
            slider.value = Float(stepped)
        }
    }

    fileprivate func steppedValue(_ raw: Double) -> Double {
        guard step > 0 else { return min(max(raw, range.lowerBound), range.upperBound) }
        let clamped = min(max(raw, range.lowerBound), range.upperBound)
        let units = ((clamped - range.lowerBound) / step).rounded()
        return min(range.upperBound, range.lowerBound + units * step)
    }

    final class Coordinator: NSObject {
        var parent: ExclusiveSlider

        init(_ parent: ExclusiveSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ slider: UISlider) {
            let stepped = parent.steppedValue(Double(slider.value))
            slider.value = Float(stepped)
            if parent.value != stepped {
                parent.value = stepped
            }
        }
    }
}
