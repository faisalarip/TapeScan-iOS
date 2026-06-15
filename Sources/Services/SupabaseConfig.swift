// SupabaseConfig.swift — backend endpoint configuration (M7).
//
// OWNER INPUT: replace both placeholders with the real project values
// (Supabase dashboard → Settings → API). The anon key is PUBLIC by design —
// row-level security policies are the actual protection (see
// supabase/migrations/0001_init.sql).

import Foundation

public enum SupabaseConfig {
    /// e.g. https://abcdefgh.supabase.co — the BASE project URL (no /rest/v1 path).
    public static let url = URL(string: "https://ujipouimfepmsiseomxq.supabase.co")!
    /// The project's anon (public) API key. Public by design — RLS is the real
    /// protection (see supabase/migrations/0001_init.sql).
    public static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqaXBvdWltZmVwbXNpc2VvbXhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1MzMwMjMsImV4cCI6MjA5NTEwOTAyM30.vAsq9q93xe5I51GeflD4MvWVlMrG030PVTwjGQLv9rM"

    /// True once real credentials are in place. Auth/sync UI stays functional
    /// but surfaces an honest "not configured" failure until then — it never
    /// fakes success.
    public static var isConfigured: Bool {
        !anonKey.hasPrefix("REPLACE") && !(url.host() ?? "").hasPrefix("REPLACE")
    }
}
