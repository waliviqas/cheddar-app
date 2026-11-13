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
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.sessions) { session in
                        NavigationLink(value: Route.session(session.id)) {
                            SessionRow(session: session, onWatch: session.video == nil ? nil : {
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
        .navigationTitle("Sessions")
        .toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(item: $watching, onDismiss: keepUpright) { session in
            if let url = session.video.flatMap(Demo.video) {
                SessionVideoView(session: session, url: url)
            }
        }
    }
}

private struct SessionRow: View {
    let session: Session
    let onWatch: (() -> Void)?   // plays the whole session's video; nil when there isn't one

    // Stacked top to bottom so it fits a phone held upright: picture, date, then the numbers and the net.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .overlay(Image(session.cover).resizable().scaledToFill())
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if let onWatch {
                        Button(action: onWatch) {
                            Label("Watch full session", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .padding(10)
                    }
                }
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
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08)))
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
