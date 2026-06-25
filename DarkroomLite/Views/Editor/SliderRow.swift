import SwiftUI

/// A labeled slider with a live numeric readout and double-click-to-reset, used by every
/// edit panel so each adjustment looks and behaves consistently.
///
/// `value` is backed by an `@Observable` property (`EditorViewModel.edit` or similar), and
/// writing to it on every tick of a drag — which a native `Slider` does, often 60+ times a
/// second — invalidates every other slider row currently on screen that reads the same
/// `@Observable` property, since Swift's Observation tracks at whole-property granularity,
/// not per-field. That cascade, not the (already-debounced, already-backgrounded) image
/// render, is what makes dragging feel laggy when several panels are expanded. To avoid it,
/// the `Slider` itself is bound to a purely local `liveValue` while dragging — instant and
/// free of any cross-row invalidation — and only flushes into `value` at a capped rate, with
/// an exact final flush on release.
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = -100...100
    var defaultValue: Double = 0
    var step: Double = 1
    var format: (Double) -> String = { String(format: "%.0f", $0) }
    /// Purely decorative gradient drawn under the slider, e.g. blue-to-yellow for Temperature,
    /// matching Lightroom's color-coded white balance sliders. `nil` for every other slider.
    var trackTint: Gradient? = nil
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var liveValue: Double = 0
    @State private var isDragging = false
    @State private var lastFlush: Date = .distantPast

    private static let flushInterval: TimeInterval = 1.0 / 30

    private var displayValue: Double { isDragging ? liveValue : value }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text(format(displayValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36, alignment: .trailing)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            Slider(
                value: Binding(
                    get: { displayValue },
                    set: { newValue in
                        liveValue = newValue
                        flushIfDue(newValue)
                    }
                ),
                in: range, step: step,
                onEditingChanged: { editing in
                    if editing {
                        liveValue = value
                        isDragging = true
                    } else {
                        value = liveValue
                        isDragging = false
                        lastFlush = .distantPast
                    }
                    onEditingChanged(editing)
                }
            )
            .onTapGesture(count: 2) { value = defaultValue }
            if let trackTint {
                LinearGradient(gradient: trackTint, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 3)
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
            }
        }
        .help("Double-click the slider to reset \(title) to its default value.")
    }

    private func flushIfDue(_ newValue: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastFlush) >= Self.flushInterval else { return }
        lastFlush = now
        value = newValue
    }
}
