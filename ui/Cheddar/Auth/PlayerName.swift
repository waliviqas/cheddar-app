import Foundation
import Observation
import Supabase

/*
This file's only job is: the player's name, what Cheddar calls them ("Welcome, Sam"). Signed in, it's saved on their
Cheddar account in Supabase, so it follows them to any phone. As a guest, it's saved only on this phone, and moves to
their account if they sign in later.
*/
@MainActor
@Observable
final class PlayerName {
    private(set) var name: String?

    private static let onPhoneKey = "guestName"

    init() {
        name = Self.saved()
    }

    // Reads the name again, after a sign-in or after continuing as a guest.
    func reload() {
        name = Self.saved()
    }

    func save(_ newName: String) async throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if supabase.auth.currentSession != nil {
            _ = try await supabase.auth.update(user: UserAttributes(data: ["display_name": .string(trimmed)]))
        } else {
            UserDefaults.standard.set(trimmed, forKey: Self.onPhoneKey)
        }
        name = trimmed
    }

    // A guest who signs in keeps the name they picked, unless their account already has one.
    func keepGuestName() async {
        let defaults = UserDefaults.standard
        if let guestName = defaults.string(forKey: Self.onPhoneKey), Self.saved() == nil {
            try? await save(guestName)
        }
        defaults.removeObject(forKey: Self.onPhoneKey)
        reload()
    }

    // After the account is deleted, or a guest clears their data.
    func forget() {
        UserDefaults.standard.removeObject(forKey: Self.onPhoneKey)
        name = nil
    }

    private static func saved() -> String? {
        let raw = supabase.auth.currentSession != nil
            ? supabase.auth.currentUser?.userMetadata["display_name"]?.stringValue
            : UserDefaults.standard.string(forKey: onPhoneKey)
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
