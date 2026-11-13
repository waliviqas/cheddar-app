import SwiftUI

/*
This screen's only job is: the home page and its tab bar, so the player can switch between Home, Shot Map
and Sessions. Start Session on the Home tab opens the turn-your-phone screen, and its check opens the camera,
sideways. Closing the camera comes back here.
*/
enum Route: Hashable {
    case session(Session.ID)
}

struct HomeView: View {
    @State private var store = SessionStore()
    @State private var sessionsPath: [Route] = []
    @State private var turning = false
    @State private var filming = false

    var body: some View {
        TabView {
            NavigationStack {
                ZStack(alignment: .top) {
                    Theme.background.ignoresSafeArea()
                    Button { turning = true } label: {
                        Label("Start Session", systemImage: "record.circle")
                            .font(.headline)
                            .foregroundStyle(Theme.navy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.cheddar, in: Capsule())
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 12)  // just under the Home title; the rest of the page is for stats later
                }
                .navigationTitle("Home")
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                ShotMapView()
            }
            .tabItem { Label("Shot Map", systemImage: "scope") }

            NavigationStack(path: $sessionsPath) {
                SessionsView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .session(let id):
                            if let session = store.session(id) {
                                SessionDetailView(session: session)
                            }
                        }
                    }
            }
            .tabItem { Label("Sessions", systemImage: "list.bullet") }
        }
        .environment(store)
        .environment(\.speedRange, store.speedRange)
        .tint(Theme.cheddar)
        .fullScreenCover(isPresented: $turning) {
            TurnPhoneView {
                turnSideways()
                filming = true
            }
            .fullScreenCover(isPresented: $filming, onDismiss: {
                keepUpright()
                turning = false
            }) {
                RecordView()
            }
        }
    }
}

#Preview {
    HomeView()
}
