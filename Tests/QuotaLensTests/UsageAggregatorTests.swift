import XCTest
@testable import QuotaLens

final class UsageAggregatorTests: XCTestCase {

    private func event(
        secondsAgo: Double, tokens: Double,
        session: String = "s1", key: String = UUID().uuidString
    ) -> UsageEvent {
        UsageEvent(
            timestamp: Date().addingTimeInterval(-secondsAgo),
            sessionId: session, model: "claude-sonnet-4",
            inputTokens: tokens, outputTokens: 0,
            cacheCreationTokens: 0, cacheReadTokens: 0,
            dedupeKey: key
        )
    }

    func testDeduplicateKeepsFirst() {
        let a = event(secondsAgo: 600, tokens: 100, key: "dup")
        let b = event(secondsAgo: 300, tokens: 999, key: "dup")
        let out = UsageAggregator.deduplicate([a, b])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out.first?.totalTokens, 100)
    }

    func testSlidingExcludesOutsideWindow() {
        let recent = event(secondsAgo: 3600, tokens: 100, key: "a")    // 1h ago
        let old = event(secondsAgo: 7 * 3600, tokens: 500, key: "b")   // 7h ago
        let since = Date().addingTimeInterval(-5 * 3600)
        XCTAssertEqual(UsageAggregator.slidingTokens([recent, old], since: since), 100)
    }

    func testActiveBlockResetsAfterGap() {
        let now = Date()
        let first = UsageEvent(timestamp: now.addingTimeInterval(-6 * 3600 - 600),
                               sessionId: "s", model: "m", inputTokens: 1000, outputTokens: 0,
                               cacheCreationTokens: 0, cacheReadTokens: 0, dedupeKey: "1")
        let second = UsageEvent(timestamp: now.addingTimeInterval(-600),
                                sessionId: "s", model: "m", inputTokens: 200, outputTokens: 0,
                                cacheCreationTokens: 0, cacheReadTokens: 0, dedupeKey: "2")
        let block = UsageAggregator.activeBlock([first, second], now: now)
        XCTAssertEqual(block?.tokens, 200, "A >5h gap should start a fresh block")
    }

    func testExpiredBlockIsEmpty() {
        let now = Date()
        let old = UsageEvent(timestamp: now.addingTimeInterval(-6 * 3600),
                             sessionId: "s", model: "m", inputTokens: 1000, outputTokens: 0,
                             cacheCreationTokens: 0, cacheReadTokens: 0, dedupeKey: "1")
        XCTAssertEqual(UsageAggregator.activeBlock([old], now: now)?.tokens, 0)
    }

    func testSessionWindowPicksMostRecentSession() {
        let now = Date()
        let s1 = UsageEvent(timestamp: now.addingTimeInterval(-3600), sessionId: "s1", model: "m",
                            inputTokens: 100, outputTokens: 0, cacheCreationTokens: 0,
                            cacheReadTokens: 0, dedupeKey: "a")
        let s2 = UsageEvent(timestamp: now.addingTimeInterval(-60), sessionId: "s2", model: "m",
                            inputTokens: 50, outputTokens: 0, cacheCreationTokens: 0,
                            cacheReadTokens: 0, dedupeKey: "b")
        let usages = UsageAggregator.aggregate(
            events: [s1, s2], toolName: "t", now: now,
            baseline5h: 1000, baseline7d: 10000, mode: .sliding)
        XCTAssertEqual(usages.first { $0.windowType == .session }?.usedTokens, 50)
    }

    func testHourlyBucketsPlaceEventsByHour() {
        let now = Date()
        let e0 = event(secondsAgo: 30 * 60, tokens: 10, key: "x")   // ~0.5h ago → last bucket
        let e3 = event(secondsAgo: 3 * 3600 + 60, tokens: 20, key: "y") // ~3h ago
        let buckets = UsageAggregator.hourlyBuckets([e0, e3], now: now, hours: 6)
        XCTAssertEqual(buckets.count, 6)
        XCTAssertEqual(buckets.reduce(0, +), 30)
        XCTAssertEqual(buckets.last, 10)
    }
}
