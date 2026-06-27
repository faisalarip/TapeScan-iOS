// AttributionTracker.swift — the IAP funnel-memory value type (Analytics).
//
// This is the *attribution spine* for the Firebase GA4 work: one canonical
// source string carried end-to-end so we can answer "which feature / entry
// point contributes most to IAP conversions" without scattering bespoke state
// across views. AppState owns exactly one of these and persists its durable
// subset as JSON; every paywall trigger site and value-moment mutates it
// through thin AppState pass-throughs (beginPaywall / recordValueFeature / …).
//
// Design notes (mirrors `ProductMapping` being pure):
//  - Pure, `Sendable` value type. NO Firebase symbols here — this file compiles
//    identically with or without the SDK and is fully unit-testable in
//    isolation (see AttributionTrackerTests). Any Firebase usage lives in
//    AnalyticsService.swift behind `#if canImport(FirebaseAnalytics)`.
//  - SESSION-ONLY vs PERSISTED is the central distinction. Session-only fields
//    (pendingSource, firstValueFeature, lastValueFeature, touchpointCount) live
//    only for the current cold-start run and reset to their defaults on the
//    next launch. Persisted fields (lastSource, impressionsBySource,
//    firstOpenAt, sessionCount) survive across launches via Codable — `CodingKeys`
//    deliberately excludes the session-only fields so decoding a stored tracker
//    yields fresh session state.
//  - LAST-TOUCH attribution: `pendingSource` is the *live* paywall's source,
//    `lastSource` survives dismissal so the source-less StoreKit listener can
//    still attribute a later Ask-to-Buy approval or renewal. `conversionSource`
//    folds the two with the correct precedence (pending first, then last).

import Foundation

// MARK: - AttributionTracker

/// Pure funnel-memory for IAP entry-point attribution. Owned by `AppState`,
/// mutated through AppState pass-throughs at trigger sites / value-moments, and
/// read by `PaywallView` (and the StoreKit listener) when stamping analytics
/// events. Codable persists ONLY the durable subset — see `CodingKeys`.
public struct AttributionTracker: Codable, Equatable, Sendable {

    // MARK: Source spine

    /// SESSION-ONLY. The source of the paywall that is *currently on screen*
    /// (e.g. "export_quota_meter"). Set by `beginPaywall(source:)` immediately
    /// before the paywall is presented, and cleared by `endPaywall()` on
    /// dismiss. This is the value used for live impression / purchase events.
    public var pendingSource: String?

    /// PERSISTED. The last source that opened a paywall. Unlike `pendingSource`
    /// it is NOT cleared on dismiss — it survives so the source-less StoreKit
    /// transaction listener (renewals, refunds, Ask-to-Buy approvals that land
    /// after the paywall closed) can still attribute the change to the entry
    /// point that originally seeded it.
    public var lastSource: String?

    /// PERSISTED. Per-source tally of how many times each entry point has shown
    /// the paywall (a paywall_view "impression"). Bumped in `recordImpression()`.
    /// `private(set)` so the only way to mutate it is through that method,
    /// keeping the touchpoint accounting in one place.
    public private(set) var impressionsBySource: [String: Int]

    // MARK: Value-feature memory

    /// SESSION-ONLY. The first core value-moment seen this session (e.g.
    /// "measure_finished"). Set ONCE per session by `recordValueFeature(_:)`
    /// and never overwritten thereafter — this is "which feature first hooked
    /// the user before they hit the paywall".
    public var firstValueFeature: String?

    /// SESSION-ONLY. The most recent core value-moment seen this session.
    /// Overwritten on every `recordValueFeature(_:)` call.
    public var lastValueFeature: String?

    /// SESSION-ONLY. Number of paywall impressions this session. Incremented in
    /// `recordImpression()` and attached to paywall_view / purchase events so we
    /// can correlate "how many nudges before conversion". `private(set)` for the
    /// same single-mutation-point reason as `impressionsBySource`.
    public private(set) var touchpointCount: Int

    // MARK: Time / sessions to convert

    /// PERSISTED. Timestamp of the very first app open, set ONCE in
    /// `startSession(now:)`. Basis for `timeToConvertBucket(now:)`.
    public var firstOpenAt: Date?

    /// PERSISTED. Count of cold starts, incremented once per launch in
    /// `startSession(now:)`. Reported as `sessions_to_convert` at purchase time.
    public var sessionCount: Int

    // MARK: Init

    /// Designated initializer. Only the PERSISTED fields are accepted (these are
    /// what we decode / rehydrate); session-only fields always start at their
    /// fresh defaults, which is exactly the desired behaviour on a cold start.
    public init(lastSource: String? = nil,
                impressionsBySource: [String: Int] = [:],
                firstOpenAt: Date? = nil,
                sessionCount: Int = 0) {
        // Persisted subset (caller-supplied / decoded).
        self.lastSource = lastSource
        self.impressionsBySource = impressionsBySource
        self.firstOpenAt = firstOpenAt
        self.sessionCount = sessionCount
        // Session-only subset — always fresh for the current run.
        self.pendingSource = nil
        self.firstValueFeature = nil
        self.lastValueFeature = nil
        self.touchpointCount = 0
    }

    // MARK: Source spine mutations

    /// Called IMMEDIATELY before a paywall is presented. Records the source on
    /// both the session-only `pendingSource` (the live paywall) and the
    /// persisted `lastSource` (for later out-of-band attribution).
    ///
    /// This is the crux of telling otherwise-identical entry points apart: two
    /// ExportView trigger sites share a single `showPaywall` binding, so each
    /// must call this with its own distinct source string right before flipping
    /// the binding.
    public mutating func beginPaywall(source: String) {
        pendingSource = source
        lastSource = source
    }

    /// Called from the paywall's appearance (paywall_view). Bumps the session
    /// touchpoint count and the per-source impression tally, then returns the
    /// source that should be stamped on the impression event.
    ///
    /// Returns `pendingSource` (may be nil if, defensively, no trigger site set
    /// one — callers stamp "unknown" in that case).
    @discardableResult
    public mutating func recordImpression() -> String? {
        touchpointCount += 1
        if let source = pendingSource {
            impressionsBySource[source, default: 0] += 1
        }
        return pendingSource
    }

    /// Called when the paywall is dismissed. Clears ONLY the live
    /// `pendingSource`; `lastSource` is deliberately left intact so a later
    /// source-less transaction event can still be attributed.
    public mutating func endPaywall() {
        pendingSource = nil
    }

    /// The source to attribute a conversion to. Prefers the live paywall's
    /// `pendingSource`; falls back to the persisted `lastSource` when the
    /// conversion arrives out-of-band (Ask-to-Buy approval / renewal handled by
    /// the StoreKit listener after the paywall has already closed).
    public var conversionSource: String? {
        pendingSource ?? lastSource
    }

    // MARK: Value-feature mutations

    /// Records a core value-moment (e.g. "measure_finished", "export_generated").
    /// Always updates `lastValueFeature`; sets `firstValueFeature` only the first
    /// time this session (it is never overwritten once set).
    public mutating func recordValueFeature(_ feature: String) {
        lastValueFeature = feature
        if firstValueFeature == nil {
            firstValueFeature = feature
        }
    }

    // MARK: Session lifecycle

    /// Called once per cold start (from the root `.task`). Stamps `firstOpenAt`
    /// the very first time only, and increments `sessionCount` every launch.
    public mutating func startSession(now: Date) {
        if firstOpenAt == nil {
            firstOpenAt = now
        }
        sessionCount += 1
    }

    /// Low-cardinality "time to convert" bucket for GA4 segmentation. Computed
    /// from the elapsed interval since `firstOpenAt`. A bucketed string (rather
    /// than a raw interval) keeps the custom dimension explorable in GA4.
    ///
    /// Buckets:
    ///  - "same_session" — converted within an hour of first open (heuristic
    ///    for "same sitting"; we don't track explicit session boundaries here).
    ///  - "under_24h"    — same day-ish, more than an hour in.
    ///  - "1_7d"         — within the first week.
    ///  - "over_7d"      — longer than a week (also the safe fallback when
    ///                     `firstOpenAt` is somehow unset).
    public func timeToConvertBucket(now: Date) -> String {
        guard let firstOpenAt else { return "over_7d" }
        let elapsed = now.timeIntervalSince(firstOpenAt)
        let hour: TimeInterval = 60 * 60
        let day: TimeInterval = 24 * hour
        if elapsed < hour {
            return "same_session"
        } else if elapsed < day {
            return "under_24h"
        } else if elapsed < 7 * day {
            return "1_7d"
        } else {
            return "over_7d"
        }
    }

    // MARK: Codable — persist ONLY the durable subset

    /// CodingKeys intentionally lists ONLY the persisted fields. Session-only
    /// fields (pendingSource, firstValueFeature, lastValueFeature,
    /// touchpointCount) are absent, so:
    ///  - encoding writes just the durable subset, and
    ///  - decoding produces an instance whose session-only fields are at their
    ///    fresh defaults (set in `init(from:)` below) — exactly what we want on
    ///    a new cold start that rehydrates persisted attribution.
    private enum CodingKeys: String, CodingKey {
        case lastSource
        case impressionsBySource
        case firstOpenAt
        case sessionCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Persisted fields — tolerate absence so older / partial blobs still
        // decode rather than throwing (decodeIfPresent + defaults).
        let lastSource = try container.decodeIfPresent(String.self, forKey: .lastSource)
        let impressionsBySource = try container.decodeIfPresent([String: Int].self, forKey: .impressionsBySource) ?? [:]
        let firstOpenAt = try container.decodeIfPresent(Date.self, forKey: .firstOpenAt)
        let sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount) ?? 0
        // Route through the designated init so session-only fields reset to
        // their fresh defaults — keeping the "decode resets the session" rule in
        // exactly one place.
        self.init(lastSource: lastSource,
                  impressionsBySource: impressionsBySource,
                  firstOpenAt: firstOpenAt,
                  sessionCount: sessionCount)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode ONLY the durable subset. encodeIfPresent keeps nils out of the
        // JSON so a brand-new tracker serializes compactly.
        try container.encodeIfPresent(lastSource, forKey: .lastSource)
        try container.encode(impressionsBySource, forKey: .impressionsBySource)
        try container.encodeIfPresent(firstOpenAt, forKey: .firstOpenAt)
        try container.encode(sessionCount, forKey: .sessionCount)
    }
}
