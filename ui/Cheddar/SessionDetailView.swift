import SwiftUI

/*
This screen's only job is: one logged session — its numbers, where the pucks went (tap a dot to watch it), and every shot.
*/
struct SessionDetailView: View {
    let session: Session
    let onAllSessions: () -> Void
    @Environment(SessionStore.self) private var store
    @State private var replay: Shot?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 20) {
                        Stat(title: "SHOTS", value: "\(session.shots.count)")
                        Stat(title: "TOP SPEED", value: session.topSpeed.mphText, highlight: true)
                        Stat(title: "AVERAGE", value: session.average.mphText)
                        Stat(title: "LENGTH", value: session.duration.length)
                        Spacer()
                        if store.justLogged == session.id {
                            Label("Session logged", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .fixedSize()
                                .foregroundStyle(.green)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.green.opacity(0.15), in: Capsule())
                        }
                        Button(action: onAllSessions) {
                            Label("All Sessions", systemImage: "list.bullet")
                                .font(.subheadline.weight(.semibold))
                                .fixedSize()
                                .foregroundStyle(Theme.navy)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Theme.cheddar, in: Capsule())
                        }
                    }
                    HStack(alignment: .top, spacing: 12) {
                        MapCard(title: "WHERE IT WENT", hint: "Tap a dot") {
                            NetMapView(shots: session.shots) { replay = $0 }
                        }
                        .frame(height: 260)
                        VStack(alignment: .leading, spacing: 10) {
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
                        .frame(maxWidth: .infinity)
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
        .fullScreenCover(item: $replay) { ShotReplayView(shot: $0) }
    }
}
