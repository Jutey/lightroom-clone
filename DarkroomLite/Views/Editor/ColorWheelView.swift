import SwiftUI

/// A single hue/saturation color wheel, used three times (shadows/midtones/highlights) by
/// the Color Grading panel. Angle around the wheel selects hue (0...360), distance from
/// center selects saturation (0...100); luminance is a separate slider since it isn't part
/// of the wheel's polar geometry.
struct ColorWheelView: View {
    @Binding var wheel: ColorGradingWheel
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2

            ZStack {
                Circle()
                    .fill(AngularGradient(gradient: Gradient(colors: hueGradientColors), center: .center))
                    .overlay(
                        Circle().fill(
                            RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: radius)
                        )
                    )
                    .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))

                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 3, height: 3)

                handle(center: center, radius: radius)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onEditingChanged(true)
                        update(at: value.location, center: center, radius: radius)
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
        }
        .frame(width: 90, height: 90)
    }

    private var hueGradientColors: [Color] {
        stride(from: 0.0, through: 360.0, by: 30.0).map { Color(hue: $0 / 360, saturation: 1, brightness: 1) }
    }

    private func handle(center: CGPoint, radius: CGFloat) -> some View {
        let fraction = min(wheel.saturation, 100) / 100
        let angle = Angle(degrees: wheel.hue)
        let x = center.x + cos(angle.radians) * radius * fraction
        let y = center.y + sin(angle.radians) * radius * fraction
        return Circle()
            .fill(wheel.saturation > 0 ? Color(hue: wheel.hue / 360, saturation: 1, brightness: 1) : Color.gray)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .shadow(radius: 1)
            .position(x: x, y: y)
    }

    private func update(at location: CGPoint, center: CGPoint, radius: CGFloat) {
        guard radius > 0 else { return }
        let dx = location.x - center.x
        let dy = location.y - center.y
        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        let distance = min(sqrt(dx * dx + dy * dy), radius)
        wheel.hue = degrees
        wheel.saturation = (distance / radius) * 100
    }
}
