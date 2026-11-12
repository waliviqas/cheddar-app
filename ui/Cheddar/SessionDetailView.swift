import SwiftUI

/*
This screen's only job is: one logged session — its numbers, where the pucks went (tap a dot to watch it), and every shot.
Stacked top to bottom so it fits a phone held upright.
*/
struct SessionDetailView: View {
    let session: Session
    @Environment(SessionStore.self) private var store
    @State private var replay: Shot?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Stat(title: "SHOTS", value: "\(session.shots.count)")
                        Stat(title: "TOP SPEED", value: session.topSpeed.mphText, highlight: true)
                        Stat(title: "AVERAGE", value: session.average.mphText)
                        Stat(title: "LENGTH", value: session.duration.length)
                    }
                    if store.justLogged == session.id {
                        Label("Session logged", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                    MapCard(title: "WHERE IT WENT", hint: "Tap a dot") {
                        NetMapView(shots: session.shots) { shot in letScreenTurn(); replay = shot }
                    }
                    Text("EVERY SHOT")
                        .font(.caption.weight(.bold))
                        .kerning(1.5)
                        .foregroundStyle(.white.opacity(0.6))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(session.shots) { shot in
                            ShotChip(shot: shot)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(session.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .fullScreenCover(item: $replay, onDismiss: keepUpright) { ShotReplayView(shot: $0) }
    }
}
