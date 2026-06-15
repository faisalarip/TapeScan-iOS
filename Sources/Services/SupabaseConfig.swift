// SupabaseConfig.swift — backend endpoint configuration (M7).
//
// OWNER INPUT: replace both placeholders with the real project values
// (Supabase dashboard → Settings → API). The anon key is PUBLIC by design —
// row-level security policies are the actual protection (see
// supabase/migrations/0001_init.sql).

import Foundation

public enum SupabaseConfig {
    /// e.g. https://abcdefgh.supabase.co — the BASE project URL (no /rest/v1 path).
    /// Dedicated project "TapeScan-iOS" (ejapwzjrnwvgusqqueky).
    public static let url = URL(string: "https://ejapwzjrnwvgusqqueky.supabase.co")!
    /// The project's anon (public) API key. Public by design — RLS is the real
    /// protection (see supabase/migrations/0001_init.sql).
    public static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqYXB3empybnd2Z3VzcXF1ZWt5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MjkwNDksImV4cCI6MjA5NzEwNTA0OX0.unxsLcEdzPBfBgr23w-msP-2Ggd6K50KrnQiVGA5Unk"

    /// True once real credentials are in place. Auth/sync UI stays functional
    /// but surfaces an honest "not configured" failure until then — it never
    /// fakes success.
    public static var isConfigured: Bool {
        !anonKey.hasPrefix("REPLACE") && !(url.host() ?? "").hasPrefix("REPLACE")
    }
}
