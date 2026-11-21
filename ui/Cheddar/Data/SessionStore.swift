import Foundation
import Observation
import Supabase

/*
This class's only job is: keep the list of logged sessions, newest first. A signed-in player's list is saved in a file
on this phone, one file per player, so it's still there after the app closes. A guest's sessions are never kept.
*/
@MainActor
@Observable
final class SessionStore {
    private(set) var sessions: [Session] = []
    private(set) var justLogged: Session.ID?
    private var file: URL?

    // Reads the signed-in player's saved sessions; a guest has none.
    func load() {
        file = supabase.auth.currentUser.map {
            URL.applicationSupportDirectory.appending(path: "Sessions/\($0.id.uuidString).json")
        }
        sessions = file.flatMap { try? JSONDecoder().decode([Session].self, from: Data(contentsOf: $0)) } ?? []
    }

    func log(_ session: Session) {
        sessions.insert(session, at: 0)
        justLogged = session.id
        save()
    }

    // After the account is deleted: its sessions and their videos are deleted too, from this phone and from iCloud.
    func forgetEverything() {
        sessions.compactMap(\.video).forEach(SavedVideos.delete)
        if let file { try? FileManager.default.removeItem(at: file) }
        sessions = []
    }

    // Slowest to fastest readable shot across every session. The shot maps size and color dots against it,
    // so a new record makes older shots look slower. nil until there's a shot with a speed.
    var speedRange: ClosedRange<Double>? {
        let speeds = sessions.flatMap(\.speeds)
        guard let slowest = speeds.min(), let fastest = speeds.max() else { return nil }
        return slowest...fastest
    }

    func session(_ id: Session.ID) -> Session? {
        sessions.first { $0.id == id }
    }

    // The session a shot came from. Shot numbers repeat from session to session; replay clip names don't.
    func session(of shot: Shot) -> Session? {
        guard let clip = shot.clip else { return nil }
        return sessions.first { $0.shots.contains { $0.clip == clip } }
    }

    private func save() {
        guard let file else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(sessions).write(to: file, options: .atomic)
    }
}
