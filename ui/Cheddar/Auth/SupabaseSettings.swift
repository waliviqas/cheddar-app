import Foundation
import Supabase

/*
This file's only job is: connect Cheddar to its Supabase project. The publishable key is meant to sit inside the
app; the RLS lock on each table is what keeps one player's data away from everyone else.
*/
enum SupabaseSettings {
    static let url = URL(string: "https://jkgwlumqdngbwbsrpujo.supabase.co")!
    static let publishableKey = "sb_publishable_aUcXtSDA9SCfOqc9hCePVg_4w50ik4n"
}

// The one connection the whole app shares. It also keeps the player's login saved on the phone.
let supabase = SupabaseClient(supabaseURL: SupabaseSettings.url, supabaseKey: SupabaseSettings.publishableKey)
