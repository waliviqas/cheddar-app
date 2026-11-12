import Observation

/*
This class's only job is: keep the list of logged sessions, newest first.
*/
@MainActor
@Observable
final class SessionStore {
    private(set) var sessions: [Session] = [Demo.nov11, Demo.oct23]
    private(set) var justLogged: Session.ID?

    func log(_ session: Session) {
        sessions.insert(session, at: 0)
        justLogged = session.id
    }

    // Back to the built-in sessions: Nov 11 and Oct 23.
    func reset() {
        sessions = [Demo.nov11, Demo.oct23]
        justLogged = nil
    }

    func session(_ id: Session.ID) -> Session? {
        sessions.first { $0.id == id }
    }

    // The session a shot came from. Shot numbers repeat from session to session; replay clip names don't.
    func session(of shot: Shot) -> Session? {
        guard let clip = shot.clip else { return nil }
        return sessions.first { $0.shots.contains { $0.clip == clip } }
    }
}
