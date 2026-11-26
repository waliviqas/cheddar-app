import SwiftUI

/*
This view's only job is: draw one of the net's corner dots as a ring that's easy to see and grab. It pops in when
tapped, pulses while the net isn't locked, grows a crosshair while it's dragged, and flashes once when the net locks.
*/
struct CornerRing: View {
    let color: Color
    let dragging: Bool
    let locked: Bool

    @State private var shown = false
    @State private var flashes = 0

    var body: some View {
        ZStack {
            if !locked {
                pulse
            }
            Circle()
                .fill(Theme.navy.opacity(0.25))
                .overlay(Circle().stroke(Theme.navy.opacity(0.5), lineWidth: 6.5))  // keeps the ring readable on bright concrete
                .overlay(Circle().stroke(color, lineWidth: 3.2))
                .frame(width: dragging ? 42 : 32, height: dragging ? 42 : 32)
            if dragging {
                Crosshair()
                    .stroke(color, lineWidth: 1.6)
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
        }
        .keyframeAnimator(initialValue: 1.0, trigger: flashes) { content, progress in
            content.overlay {
                Circle()
                    .stroke(.white, lineWidth: 3.5 * (1 - progress))
                    .frame(width: 32 + 56 * progress, height: 32 + 56 * progress)
                    .opacity(1 - progress)
            }
        } keyframes: { _ in
            KeyframeTrack {
                MoveKeyframe(0.0)
                LinearKeyframe(1.0, duration: 0.6, timingCurve: .easeOut)
            }
        }
        .scaleEffect(shown ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragging)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { shown = true }
        }
        .onChange(of: locked) { _, isLocked in
            if isLocked { flashes += 1 }
        }
    }

    // A ring that grows and fades every 1.4 s, so a dot still waiting on the net catches the eye.
    private var pulse: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: 32 * (1 + phase), height: 32 * (1 + phase))
                .opacity(0.7 * (1 - phase))
        }
        .frame(width: 64, height: 64)
    }
}

private struct Crosshair: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}
