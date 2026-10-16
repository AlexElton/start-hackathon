import SwiftUI

/// Slim vertical zoom control that runs the full height of the side: just a line and a knob.
/// Top zooms in, bottom zooms out.
struct ZoomSlider: View {
    /// 0 = closest (top), 1 = furthest (bottom).
    @Binding var value: Double
    @Binding var isActive: Bool

    private let thumbSize: CGFloat = 14
    private let hitWidth: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.height - thumbSize, 1)
            ZStack(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.7))
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.35), radius: 1.5)
                    .padding(.vertical, thumbSize / 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2.5, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .scaleEffect(isActive ? 1.3 : 1)
                    .offset(y: travel * value)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isActive = true
                        value = ((drag.location.y - thumbSize / 2) / travel).clamped(to: 0...1)
                    }
                    .onEnded { _ in isActive = false }
            )
            .animation(.snappy(duration: 0.15), value: isActive)
        }
        .frame(width: hitWidth)
        .sensoryFeedback(.selection, trigger: isActive)
        .accessibilityElement()
        .accessibilityLabel("Zoom")
        .accessibilityValue("\(Int((1 - value) * 100)) prosent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = (value - 0.1).clamped(to: 0...1)
            case .decrement: value = (value + 0.1).clamped(to: 0...1)
            @unknown default: break
            }
        }
    }
}

#Preview {
    @Previewable @State var value = 0.4
    @Previewable @State var active = false
    ZoomSlider(value: $value, isActive: $active)
        .frame(height: 500)
        .padding()
        .background(.gray)
}
