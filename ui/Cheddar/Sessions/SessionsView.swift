import SwiftUI

/*
This screen's only job is: list every logged session so the user can scroll through them and open one.
*/
struct SessionsView: View {
    @Environment(SessionStore.self) private var store
    @State private var watching: Session?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if store.sessions.isEmpty {
                NoSessionsYet()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.sessions) { session in
                            NavigationLink(value: Route.session(session.id)) {
                                SessionRow(session: session, onWatch: session.video.flatMap(SavedVideos.url) == nil ? nil : {
                                    letScreenTurn()
                                    watching = session
                                })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("Sessions")
        .toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(item: $watching, onDismiss: keepUpright) { session in
            if let url = session.video.flatMap(SavedVideos.url) {
                SessionVideoView(session: session, url: url)
            }
        }
    }
}

private struct SessionRow: View {
    let session: Session
    let onWatch: (() -> Void)?   // plays the whole session's video; nil when there isn't one

    // Stacked top to bottom so it fits a phone held upright: date, the numbers and the net, then the video button.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    Text("\(session.shots.count) \(session.shots.count == 1 ? "shot" : "shots") · \(session.duration.length)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.4))
            }
            HStack(spacing: 18) {
                Stat(title: "TOP", value: session.topSpeed.mphText, highlight: true)
                Stat(title: "AVG", value: session.average.mphText)
                Spacer()
                NetMapView(shots: session.shots)
                    .frame(width: 110)
            }
            if let onWatch {
                Button(action: onWatch) {
                    Label("Watch full session", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08)))
    }
}

// What Sessions and Shot Map show before the player has recorded anything, or to a guest with a lock: the logo's
// cheese puck, hovering over its shadow on a patch of ice. The shadow shrinks and fades as the puck rises. Holds still
// with Reduce Motion on.
struct NoSessionsYet: View {
    var message = "No sessions yet"
    var locked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let lift = reduceMotion ? 0.5 : (1 + sin(t * 2 * .pi / 2.6)) / 2   // 0 lowest … 1 highest
                let tilt = reduceMotion ? 0 : 0.05 * sin(t * 2 * .pi / 3.4)        // a slow rock, in radians
                Canvas { ctx, size in
                    let floor = CGPoint(x: size.width / 2, y: size.height - 24)
                    ctx.fill(Path(ellipseIn: CGRect(x: floor.x - 66, y: floor.y - 21, width: 132, height: 42)),
                             with: .color(.white.opacity(0.09)))
                    let shadow = CGSize(width: 92 - 26 * lift, height: 20 - 6 * lift)
                    ctx.fill(Path(ellipseIn: CGRect(x: floor.x - shadow.width / 2, y: floor.y - shadow.height / 2,
                                                    width: shadow.width, height: shadow.height)),
                             with: .color(.black.opacity(0.38 - 0.18 * lift)))
                    LogoPuck(center: CGPoint(x: floor.x, y: floor.y - 76 - 18 * lift), radius: 46, roll: tilt).draw(in: ctx)
                }
                .frame(width: 170, height: 150)
            }
            Group {
                if locked {
                    Label(message, systemImage: "lock.fill")
                } else {
                    Text(message)
                }
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// A small labeled number: "TOP 63.8".
struct Stat: View {
    let title: String
    let value: String
    var highlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2.weight(.bold))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize()
            Text(value)
                .font(Theme.display(30))
                .foregroundStyle(highlight ? Theme.cheddar : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(minWidth: 70, alignment: .leading)
    }
}
