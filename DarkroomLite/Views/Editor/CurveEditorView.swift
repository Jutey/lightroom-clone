import SwiftUI

/// Parametric RGB tone curve editor. Locked to exactly 5 fixed x-positions (0, 0.25, 0.5,
/// 0.75, 1.0) because the points feed directly into `CIFilter.toneCurve()`'s
/// point0...point4 via `ImageRenderer.applyToneCurve`, which silently no-ops unless given
/// exactly 5 points — so points can only be dragged vertically, never added, removed, or
/// moved horizontally.
struct CurveEditorView: View {
    @Binding var points: [CurvePoint]
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var draggingIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            ZStack {
                gridLines(in: rect)
                curvePath(in: rect)
                    .stroke(Color.accentColor, lineWidth: 1.5)
                ForEach(safePoints.indices, id: \.self) { index in
                    handle(at: index, in: rect)
                }
            }
            .contentShape(Rectangle())
        }
        .frame(width: 200, height: 200)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            if points.count != 5 { points = EditValues.identityCurve }
        }
    }

    private var safePoints: [CurvePoint] {
        points.count == 5 ? points : EditValues.identityCurve
    }

    private func handle(at index: Int, in rect: CGRect) -> some View {
        let point = safePoints[index]
        return Circle()
            .fill(Color.white)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
            .position(position(for: point, in: rect))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if draggingIndex == nil {
                            draggingIndex = index
                            onEditingChanged(true)
                        }
                        guard safePoints.indices.contains(index), rect.height > 0 else { return }
                        let clampedY = 1 - min(max(0, value.location.y / rect.height), 1)
                        var updated = safePoints
                        updated[index].y = clampedY
                        points = updated
                    }
                    .onEnded { _ in
                        draggingIndex = nil
                        onEditingChanged(false)
                    }
            )
    }

    private func position(for point: CurvePoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: point.x * rect.width, y: (1 - point.y) * rect.height)
    }

    private func gridLines(in rect: CGRect) -> some View {
        Path { path in
            for fraction in [0.25, 0.5, 0.75] as [CGFloat] {
                path.move(to: CGPoint(x: fraction * rect.width, y: 0))
                path.addLine(to: CGPoint(x: fraction * rect.width, y: rect.height))
                path.move(to: CGPoint(x: 0, y: fraction * rect.height))
                path.addLine(to: CGPoint(x: rect.width, y: fraction * rect.height))
            }
        }
        .stroke(Color.white.opacity(0.15), lineWidth: 1)
    }

    private func curvePath(in rect: CGRect) -> Path {
        Path { path in
            let positions = safePoints.map { position(for: $0, in: rect) }
            guard let first = positions.first else { return }
            path.move(to: first)
            for point in positions.dropFirst() {
                path.addLine(to: point)
            }
        }
    }
}
