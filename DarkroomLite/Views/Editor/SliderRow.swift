import SwiftUI

/// A labeled slider with a live numeric readout and double-click-to-reset, used by every
/// edit panel so each adjustment looks and behaves consistently.
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = -100...100
    var defaultValue: Double = 0
    var step: Double = 1
    var format: (Double) -> String = { String(format: "%.0f", $0) }
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text(format(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36, alignment: .trailing)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            Slider(value: $value, in: range, step: step, onEditingChanged: onEditingChanged)
                .onTapGesture(count: 2) { value = defaultValue }
        }
        .help("Double-click the slider to reset \(title) to its default value.")
    }
}
