import SwiftUI

/*
This screen's only job is: one logged session — its numbers, its full video, and where each shot went (numbered; tap one to watch it).
Stacked top to bottom so it fits a phone held upright.
*/
struct SessionDetailView: View {
    let session: Session
    @Environment(SessionStore.self) private var store
    @State private var replay: Shot?
    @State private var watching = false

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
                    if let video = session.video.flatMap(Demo.video) {
                        Button { letScreenTurn(); watching = true } label: {
                            Label("Watch full session", systemImage: "play.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.navy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.cheddar, in: Capsule())
                        }
                        .fullScreenCover(isPresented: $watching, onDismiss: keepUpright) {
                            SessionVideoView(session: session, url: video)
                        }
                    }
                    if store.justLogged == session.id {
                        Label("Session logged", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                    MapCard(title: "WHERE IT WENT", hint: "Tap a shot") {
                        NetMapView(shots: session.shots, numbered: true) { shot in letScreenTurn(); replay = shot }
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
        .fullScreenCover(item: $replay, onDismiss: keepUpright) { ShotReplayView(shot: $0, session: session) }
    }
}
