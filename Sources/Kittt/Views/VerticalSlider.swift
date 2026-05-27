import SwiftUI
import AppKit

struct VerticalSlider: NSViewRepresentable {
    @Binding var value: Float
    var range: ClosedRange<Float> = 0...1

    func makeNSView(context: Context) -> NSSlider {
        let s = NSSlider(
            value: Double(value),
            minValue: Double(range.lowerBound),
            maxValue: Double(range.upperBound),
            target: context.coordinator,
            action: #selector(Coordinator.changed(_:))
        )
        s.isVertical = true
        s.controlSize = .small
        s.isContinuous = true
        return s
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        if abs(nsView.floatValue - value) > 0.0001 {
            nsView.floatValue = value
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject {
        var parent: VerticalSlider
        init(_ parent: VerticalSlider) { self.parent = parent }

        @objc func changed(_ sender: NSSlider) {
            parent.value = sender.floatValue
        }
    }
}
