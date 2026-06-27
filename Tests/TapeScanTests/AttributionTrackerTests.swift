// AttributionTrackerTests.swift — IAP entry-point attribution spine (analytics).
//
// AttributionTracker is the one PURE new type in the Firebase GA4 analytics
// work: a Sendable value type that remembers WHICH entry point and WHICH
// in-app value-moment seeded a conversion, so the paywall_purchase_success /
// purchase events can carry first-touch + last-touch attribution without
// threading new arguments through every call site. Because it is pure, the
// whole funnel-memory contract is unit-testable with ZERO Firebase dependency
// (mirrors ProductMappingTests covering the pure ProductMapping seam).
//
// Two invariants this file pins down end-to-end:
//   1) The SOURCE spine — pendingSource is the live paywall's source (session
//      only, cleared on dismiss), lastSource is persisted so a later
//      Ask-to-Buy approval or renewal arriving through the source-less
//      StoreKit listener can still be attributed. conversionSource prefers
//      the live source, then falls back to the persisted one.
//   2) The PERSISTENCE boundary — only the durable subset (lastSource,
//      impressionsBySource, firstOpenAt, sessionCount) survives a JSON round
//      trip; the session-only fields (pendingSource, the value-features,
//      touchpointCount) reset to defaults on decode, because a fresh launch
//      is a fresh session.
//
// No Firebase symbols are referenced here, so no canImport guards are needed
// for the AttributionTracker tests. The optional DebugLoggingAnalyticsService
// test at the bottom is DEBUG-only (that impl only exists under #if DEBUG).

import XCTest
@testable import TapeScan

final class AttributionTrackerTests: XCTestCase {

    // MARK: - Source spine (last-touch entry point)

    /// beginPaywall stamps BOTH the live (session-only) source and the durable
    /// (persisted) source: pendingSource drives the open paywall's events,
    /// lastSource survives the dismiss for out-of-band attribution.
    func testBeginPaywallSetsBothPendingAndLast() {
        var t = AttributionTracker()
        XCTAssertNil(t.pendingSource)
        XCTAssertNil(t.lastSource)

        t.beginPaywall(source: PaywallSource.exportQuotaMeter)

        XCTAssertEqual(t.pendingSource, PaywallSource.exportQuotaMeter)
        XCTAssertEqual(t.lastSource, PaywallSource.exportQuotaMeter)
    }

    /// endPaywall (called on paywall dismiss) clears ONLY pendingSource.
    /// lastSource is deliberately left intact so a later Ask-to-Buy approval or
    /// renewal — which arrives without a live source — still attributes to the
    /// entry point that last opened the paywall. After dismiss, conversionSource
    /// must therefore fall back to that persisted lastSource.
    func testEndPaywallClearsPendingButKeepsLast() {
        var t = AttributionTracker()
        t.beginPaywall(source: PaywallSource.settingsUpsell)

        t.endPaywall()

        XCTAssertNil(t.pendingSource, "pendingSource is cleared on dismiss")
        XCTAssertEqual(t.lastSource, PaywallSource.settingsUpsell,
                       "lastSource survives dismiss for out-of-band attribution")
        XCTAssertEqual(t.conversionSource, PaywallSource.settingsUpsell,
                       "with no live source, conversionSource falls back to lastSource")
    }

    /// recordImpression (fired from paywall_view) bumps the global touchpoint
    /// count AND the per-source impression tally, and returns the live source so
    /// the caller can stamp it on the paywall_view event in one call.
    func testRecordImpressionBumpsTouchpointAndPerSourceTally() {
        var t = AttributionTracker()

        // Two impressions from the locked-export CTA…
        t.beginPaywall(source: PaywallSource.exportCtaLocked)
        XCTAssertEqual(t.recordImpression(), PaywallSource.exportCtaLocked,
                       "recordImpression returns the live (pending) source")
        let secondReturn = t.recordImpression()
        XCTAssertEqual(secondReturn, PaywallSource.exportCtaLocked)

        // …then one from the settings upsell.
        t.beginPaywall(source: PaywallSource.settingsUpsell)
        _ = t.recordImpression()

        XCTAssertEqual(t.touchpointCount, 3, "touchpointCount counts every impression")
        XCTAssertEqual(t.impressionsBySource[PaywallSource.exportCtaLocked], 2)
        XCTAssertEqual(t.impressionsBySource[PaywallSource.settingsUpsell], 1)
    }

    /// conversionSource is the single attribution accessor: it prefers the live
    /// pendingSource (purchase completed while the paywall is open) and only
    /// falls back to the persisted lastSource (purchase lands later, e.g. an
    /// Ask-to-Buy approval through the source-less listener). With neither set
    /// it is nil so the caller can substitute an "out_of_band"/"unknown" label.
    func testConversionSourcePrefersPendingThenLast() {
        var t = AttributionTracker()
        XCTAssertNil(t.conversionSource, "no source observed yet")

        // Only a persisted last source (e.g. restored from disk) → fall back.
        t = AttributionTracker(lastSource: PaywallSource.debug)
        XCTAssertEqual(t.conversionSource, PaywallSource.debug)

        // A live paywall open with a DIFFERENT source must WIN over lastSource.
        t.beginPaywall(source: PaywallSource.exportQuotaMeter)
        // (beginPaywall overwrites lastSource too, so prove pending wins by
        // re-pointing them apart explicitly.)
        t.lastSource = PaywallSource.debug
        t.pendingSource = PaywallSource.exportQuotaMeter
        XCTAssertEqual(t.conversionSource, PaywallSource.exportQuotaMeter,
                       "live pendingSource wins over persisted lastSource")
    }

    // MARK: - First/last value-feature (which feature seeds conversion)

    /// recordValueFeature is called at each in-app value-moment (measure_finished,
    /// room_saved, export_generated, …). firstValueFeature is set ONCE per session
    /// and never overwritten (which feature first delivered value); lastValueFeature
    /// is overwritten every time (the most recent value-moment before purchase).
    func testRecordValueFeatureSetsFirstOnceAndLastEachTime() {
        var t = AttributionTracker()
        XCTAssertNil(t.firstValueFeature)
        XCTAssertNil(t.lastValueFeature)

        t.recordValueFeature("measure_finished")
        XCTAssertEqual(t.firstValueFeature, "measure_finished")
        XCTAssertEqual(t.lastValueFeature, "measure_finished")

        t.recordValueFeature("room_saved")
        XCTAssertEqual(t.firstValueFeature, "measure_finished",
                       "firstValueFeature is sticky — set once per session")
        XCTAssertEqual(t.lastValueFeature, "room_saved",
                       "lastValueFeature tracks the most recent value-moment")

        t.recordValueFeature("export_generated")
        XCTAssertEqual(t.firstValueFeature, "measure_finished")
        XCTAssertEqual(t.lastValueFeature, "export_generated")
    }

    // MARK: - Sessions / time to convert

    /// startSession runs once per cold start: it stamps firstOpenAt exactly once
    /// (the very first launch ever) and increments sessionCount on every launch.
    /// sessions_to_convert later reads sessionCount at purchase time.
    func testStartSessionSetsFirstOpenOnceAndIncrementsCount() {
        var t = AttributionTracker()
        XCTAssertNil(t.firstOpenAt)
        XCTAssertEqual(t.sessionCount, 0)

        let firstLaunch = Date(timeIntervalSince1970: 1_700_000_000)
        t.startSession(now: firstLaunch)
        XCTAssertEqual(t.firstOpenAt, firstLaunch, "firstOpenAt stamped on first launch")
        XCTAssertEqual(t.sessionCount, 1)

        // A later cold start must NOT move firstOpenAt but MUST bump the count.
        let secondLaunch = firstLaunch.addingTimeInterval(3 * 24 * 60 * 60)
        t.startSession(now: secondLaunch)
        XCTAssertEqual(t.firstOpenAt, firstLaunch,
                       "firstOpenAt is set once and never overwritten")
        XCTAssertEqual(t.sessionCount, 2)
    }

    /// timeToConvertBucket maps (now − firstOpenAt) to a low-cardinality string
    /// so GA4 explorations stay segmentable. Boundaries:
    ///   same_session  → within the first day from first open
    ///   under_24h     → under one day (alias band; both map to the short bucket)
    ///   1_7d          → roughly 1–7 days
    ///   over_7d       → more than a week
    /// We assert clearly-inside-band values for each bucket rather than coupling
    /// to the exact threshold convention, and pin the documented vocabulary.
    func testTimeToConvertBucketBoundaries() {
        let open = Date(timeIntervalSince1970: 1_700_000_000)
        let t = AttributionTracker(firstOpenAt: open)

        let valid: Set<String> = ["same_session", "under_24h", "1_7d", "over_7d"]

        // A few minutes after first open → the short, same-day band.
        let short = t.timeToConvertBucket(now: open.addingTimeInterval(5 * 60))
        XCTAssertTrue(valid.contains(short), "bucket must be a known vocabulary value")
        XCTAssertTrue(short == "same_session" || short == "under_24h",
                      "minutes after first open is a same-session/under-24h conversion")

        // Three days after first open → the multi-day band.
        let mid = t.timeToConvertBucket(now: open.addingTimeInterval(3 * 24 * 60 * 60))
        XCTAssertEqual(mid, "1_7d", "three days falls in the 1–7 day bucket")

        // Ten days after first open → the long band.
        let long = t.timeToConvertBucket(now: open.addingTimeInterval(10 * 24 * 60 * 60))
        XCTAssertEqual(long, "over_7d", "ten days falls in the over-7-day bucket")
    }

    // MARK: - Persistence (durable subset only)

    /// Codable encodes ONLY the durable subset (lastSource, impressionsBySource,
    /// firstOpenAt, sessionCount). The session-only fields — pendingSource, the
    /// value-features, and touchpointCount — must reset to their defaults after a
    /// decode, because a relaunch starts a brand-new session.
    func testCodableRoundTripPersistsOnlyDurableSubset() throws {
        var original = AttributionTracker()
        // Durable state we expect to survive:
        original.beginPaywall(source: PaywallSource.exportQuotaMeter) // sets lastSource (+pending)
        _ = original.recordImpression()                              // impressionsBySource + touchpoint
        original.startSession(now: Date(timeIntervalSince1970: 1_700_000_000))
        original.startSession(now: Date(timeIntervalSince1970: 1_700_100_000)) // sessionCount = 2
        // Session-only state we expect to be DROPPED:
        original.recordValueFeature("measure_finished")             // first/last value-feature

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AttributionTracker.self, from: data)

        // Durable subset survives the round trip.
        XCTAssertEqual(decoded.lastSource, PaywallSource.exportQuotaMeter)
        XCTAssertEqual(decoded.impressionsBySource[PaywallSource.exportQuotaMeter], 1)
        XCTAssertEqual(decoded.firstOpenAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(decoded.sessionCount, 2)

        // Session-only fields reset to defaults on decode (new launch = new session).
        XCTAssertNil(decoded.pendingSource, "pendingSource is session-only, not persisted")
        XCTAssertNil(decoded.firstValueFeature, "firstValueFeature is session-only")
        XCTAssertNil(decoded.lastValueFeature, "lastValueFeature is session-only")
        XCTAssertEqual(decoded.touchpointCount, 0, "touchpointCount is session-only")
    }
}

// MARK: - DebugLoggingAnalyticsService (DEBUG-only sink)

#if DEBUG
/// The in-memory analytics sink used by UI/debug runs records every logged event
/// and honours the collection toggle. It's not a pure type, but it has no
/// Firebase dependency (it just appends + prints), so it's cheap to pin here:
/// log() captures events when enabled, and respects setCollectionEnabled(false).
@MainActor
final class DebugLoggingAnalyticsServiceTests: XCTestCase {

    func testLogRecordsEventsWhenEnabled() {
        let sink = DebugLoggingAnalyticsService(collectionEnabled: true)
        XCTAssertTrue(sink.isEnabled)
        XCTAssertTrue(sink.recorded.isEmpty)

        sink.log(AnalyticsEvent(AnalyticsEventName.appOpen,
                                [AnalyticsParam.isPro: .bool(false),
                                 AnalyticsParam.lidar: .bool(true)]))
        // The typed convenience overload routes through the same sink.
        sink.log(AnalyticsEventName.paywallView,
                 [AnalyticsParam.paywallSource: .string(PaywallSource.settingsUpsell)])

        XCTAssertEqual(sink.recorded.count, 2)
        XCTAssertEqual(sink.recorded.first?.name, AnalyticsEventName.appOpen)
        XCTAssertEqual(sink.recorded.last?.name, AnalyticsEventName.paywallView)
        XCTAssertEqual(sink.recorded.last?.params[AnalyticsParam.paywallSource],
                       .string(PaywallSource.settingsUpsell))
    }

    func testRespectsCollectionDisabled() {
        let sink = DebugLoggingAnalyticsService(collectionEnabled: false)
        XCTAssertFalse(sink.isEnabled, "isEnabled is gated by the collection flag")

        sink.log(AnalyticsEventName.measureFinished, [AnalyticsParam.mode: .string("distance")])

        XCTAssertTrue(sink.recorded.isEmpty,
                      "a disabled sink must not record events")
    }

    func testSetCollectionEnabledTogglesRecording() {
        let sink = DebugLoggingAnalyticsService(collectionEnabled: true)
        sink.log(AnalyticsEventName.appOpen)
        XCTAssertEqual(sink.recorded.count, 1)

        sink.setCollectionEnabled(false)
        XCTAssertFalse(sink.isEnabled)
        sink.log(AnalyticsEventName.roomSaved)
        XCTAssertEqual(sink.recorded.count, 1, "no new events while disabled")

        sink.setCollectionEnabled(true)
        sink.log(AnalyticsEventName.roomSaved)
        XCTAssertEqual(sink.recorded.count, 2, "recording resumes once re-enabled")
    }
}
#endif
