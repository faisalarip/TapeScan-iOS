// SupabaseSyncRemote.swift — SyncRemote over Supabase Postgres (M7).
//
// Tables `measurements` and `rooms` (see supabase/migrations/0001_init.sql)
// hold one jsonb payload per record with the envelope columns the merge
// rules need. RLS scopes every query to auth.uid(), so the client never
// filters by user — the database does.

import Foundation
import Supabase

public struct SupabaseSyncRemote: SyncRemote {

    private let client: SupabaseClient
    private let userID: UUID

    public init(client: SupabaseClient, userID: UUID) {
        self.client = client
        self.userID = userID
    }

    private struct Row: Codable {
        var id: UUID
        var user_id: UUID
        var collection: String
        var payload: String          // base64 of the DTO JSON
        var updated_at: Date
        var deleted_at: Date?
    }

    public func push(_ records: [SyncRecordPayload]) async throws {
        guard !records.isEmpty else { return }
        let rows = records.map { record in
            Row(id: record.id,
                user_id: userID,
                collection: record.collection,
                payload: record.payload.base64EncodedString(),
                updated_at: record.updatedAt,
                deleted_at: record.deletedAt)
        }
        for table in ["measurements", "rooms"] {
            let subset = rows.filter { $0.collection == table }
            guard !subset.isEmpty else { continue }
            try await client.from(table).upsert(subset).execute()
        }
    }

    public func pull(since: Date?) async throws -> [SyncRecordPayload] {
        var results: [SyncRecordPayload] = []
        for table in ["measurements", "rooms"] {
            var query = client.from(table).select()
            if let since {
                query = query.gt("updated_at", value: since.ISO8601Format())
            }
            let rows: [Row] = try await query.execute().value
            results += rows.map { row in
                SyncRecordPayload(id: row.id,
                                  collection: row.collection,
                                  payload: Data(base64Encoded: row.payload) ?? Data(),
                                  updatedAt: row.updated_at,
                                  deletedAt: row.deleted_at)
            }
        }
        return results
    }
}
