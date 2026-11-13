import SwiftUI

/*
This file's only job is: hold a shot to see its details. The tag is the same one the session video shows
on a held marker; a quick tap still counts as a tap.
*/

// What a held shot shows: which shot it is and how fast it went. `title` replaces "SHOT n" when given.
struct ShotTag: View {
    let shot: Shot
    var title: String? = nil

    var body: some View {
        VStack(spacing: 2) {
            Text(title ?? "SHOT \(shot.id)")
                .font(.caption.weight(.bold))
                .kerning(2)
                .foregroundStyle(Theme.cheddar)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(shot.mph.mphText)
                    .font(Theme.display(30))
                    .foregroundStyle(.white)
                Text("MPH")
                    .font(.caption2.weight(.bold))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .fixedSize()
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.navy, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.cheddar.opacity(0.5), lineWidth: 1.5))
    }
}

// Where a held dot's tag sits: just above the dot, kept between `minX` and `maxX`.
func tagPoint(above dot: CGPoint, size: CGFloat, minX: CGFloat, maxX: CGFloat) -> CGPoint {
    CGPoint(x: min(max(dot.x, minX), maxX), y: dot.y - size / 2 - 38)
}

// Hold → `holding` is `index` until you let go. Quick tap → `tap`.
struct HoldOrTap: ViewModifier {
    @Binding var holding: Int?
    let index: Int
    let tap: () -> Void

    func body(content: Content) -> some View {
        content
            .onTapGesture(perform: tap)
            .onLongPressGesture(minimumDuration: 0.3) {
                holding = index
            } onPressingChanged: { pressing in
                if !pressing, holding == index { holding = nil }
            }
    }
}
