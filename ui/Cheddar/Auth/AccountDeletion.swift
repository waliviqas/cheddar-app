import Supabase

/*
This file's only job is: delete the signed-in player's account. The app's own key isn't allowed to delete accounts,
so it calls delete_my_account in Supabase, which deletes only the caller's own account. Then it forgets the login on
this phone. With no login (the Google button is still a stand-in), there's no account to delete, so it just signs out.
*/
enum AccountDeletion {
    static func deleteMyAccount() async throws {
        guard supabase.auth.currentSession != nil else { return }
        try await supabase.rpc("delete_my_account").execute()
        try? await supabase.auth.signOut(scope: .local)
    }
}
