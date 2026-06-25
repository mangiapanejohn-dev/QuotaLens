import XCTest
@testable import QuotaLens

final class ReconcileTests: XCTestCase {

    func testOfficialOverridesLocalRatio() {
        let local = [ToolUsage(toolName: "codex", windowType: .fiveHour,
                               usedTokens: 50, limitTokens: 100, lastUpdated: Date())]
        let official: [WindowType: OfficialReading] = [
            .fiveHour: OfficialReading(percent: 0.84, source: .codexFile, fetchedAt: Date())
        ]
        let merged = Reconciler.reconcile(local: local, official: official)
        XCTAssertEqual(merged[0].usageRatio, 0.84, accuracy: 0.001)  // official wins
        XCTAssertEqual(merged[0].localRatio, 0.50, accuracy: 0.001)  // local preserved
        XCTAssertEqual(merged[0].delta ?? .nan, 0.50 - 0.84, accuracy: 0.001)
    }

    func testNoOfficialFallsBackToLocal() {
        let local = [ToolUsage(toolName: "claude-code", windowType: .sevenDay,
                               usedTokens: 40, limitTokens: 100, lastUpdated: Date())]
        let merged = Reconciler.reconcile(local: local, official: [:])
        XCTAssertNil(merged[0].official)
        XCTAssertEqual(merged[0].usageRatio, 0.40, accuracy: 0.001)
        XCTAssertNil(merged[0].delta)
    }
}

final class UnifiedRateLimitParserTests: XCTestCase {

    func testParsesLimitRemainingIntoPercent() {
        let now = Date()
        let reset = Int(now.timeIntervalSince1970) + 3600
        let headers = [
            "anthropic-ratelimit-unified-5h-limit": "1000",
            "anthropic-ratelimit-unified-5h-remaining": "250",
            "anthropic-ratelimit-unified-5h-reset": "\(reset)",
            "anthropic-ratelimit-unified-7d-limit": "7000",
            "anthropic-ratelimit-unified-7d-remaining": "6300",
        ]
        let r = UnifiedRateLimitParser.parse(headers: headers, now: now)
        XCTAssertEqual(r[.fiveHour]?.percent ?? -1, 0.75, accuracy: 0.001)
        XCTAssertEqual(r[.sevenDay]?.percent ?? -1, 0.10, accuracy: 0.001)
        XCTAssertNotNil(r[.fiveHour]?.resetsAt)
        XCTAssertEqual(r[.fiveHour]?.source, .claudeProbe)
    }

    func testIgnoresNonUnifiedHeaders() {
        let r = UnifiedRateLimitParser.parse(
            headers: ["content-type": "application/json", "x-foo": "bar"], now: Date())
        XCTAssertTrue(r.isEmpty)
    }

    func testAcceptsUtilizationField() {
        let r = UnifiedRateLimitParser.parse(
            headers: ["anthropic-ratelimit-unified-5h-utilization": "42"], now: Date())
        XCTAssertEqual(r[.fiveHour]?.percent ?? -1, 0.42, accuracy: 0.001)  // 0..100 normalized
    }
}

final class ResetDetectionTests: XCTestCase {

    private func snapshot(_ pct: Double, at: Date) -> [ToolSnapshot] {
        let u = ToolUsage(toolName: "codex", windowType: .fiveHour,
                          usedTokens: 1000, limitTokens: 0, lastUpdated: at,
                          official: OfficialReading(percent: pct, source: .codexFile, fetchedAt: at))
        return [ToolSnapshot(toolName: "codex", displayName: "Codex",
                             usages: [u], hourlyBuckets: [], available: true, updatedAt: at)]
    }

    @MainActor
    func testResetDetectedOnOfficialDecrease() {
        let svc = ResetDetectionService(persistence: PersistenceService())
        let now = Date()
        svc.observe(snapshots: snapshot(0.9, at: now.addingTimeInterval(-60)), now: now.addingTimeInterval(-60))
        XCTAssertTrue(svc.markers(for: "codex", within: 3600, now: now).isEmpty, "first reading is not a reset")
        svc.observe(snapshots: snapshot(0.1, at: now), now: now)
        XCTAssertFalse(svc.markers(for: "codex", within: 3600, now: now).isEmpty, "a drop is a reset")
    }

    @MainActor
    func testNoResetWhenMonotonic() {
        let svc = ResetDetectionService(persistence: PersistenceService())
        let now = Date()
        svc.observe(snapshots: snapshot(0.3, at: now.addingTimeInterval(-60)), now: now.addingTimeInterval(-60))
        svc.observe(snapshots: snapshot(0.5, at: now), now: now)
        XCTAssertTrue(svc.markers(for: "codex", within: 3600, now: now).isEmpty)
    }
}
