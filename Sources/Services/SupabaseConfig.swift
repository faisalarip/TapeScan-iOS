// SupabaseConfig.swift — backend endpoint configuration (M7).
//
// OWNER INPUT: replace both placeholders with the real project values
// (Supabase dashboard → Settings → API). The anon key is PUBLIC by design —
// row-level security policies are the actual protection (see
// supabase/migrations/0001_init.sql).

import Foundation

public enum SupabaseConfig {
    /// e.g. https://abcdefgh.supabase.co
    public static let url = URL(string: "https://REPLACE-WITH-PROJECT.supabase.co")!
    /// The project's anon (public) API key.
    public static let anonKey = "REPLACE_WITH_ANON_KEY"

    /// True once real credentials are in place. Auth/sync UI stays functional
    /// but surfaces an honest "not configured" failure until then — it never
    /// fakes success.
    public static var isConfigured: Bool {
        !anonKey.hasPrefix("REPLACE") && !(url.host() ?? "").hasPrefix("REPLACE")
    }
}
