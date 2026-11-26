import Supabase

/*
This file's only job is: delete the signed-in player's account. The app's own key isn't allowed to delete accounts,
so it calls delete_my_account in Supabase, which deletes only the caller's own account. Then it forgets the login on
this phone. If the login has expired and can't be renewed, it says so instead of deleting nothing.
*/
enum AccountDeletion {
    // The login on this phone expired and couldn't be renewed, so Supabase can't tell whose account to delete.
    struct SignInExpired: Error {}

    static func deleteMyAccount() async throws {
        do {
            _ = try await supabase.auth.session  // renews the login when it has expired
        } catch AuthError.sessionMissing {
            throw SignInExpired()
        }
        try await supabase.rpc("delete_my_account").execute()
        try? await supabase.auth.signOut(scope: .local)
    }
}
