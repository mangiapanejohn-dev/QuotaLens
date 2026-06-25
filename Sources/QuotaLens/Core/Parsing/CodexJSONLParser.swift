import Foundation

/// Authoritative rate-limit snapshot Codex writes into each `token_count` event.
struct CodexRateSnapshot: Sendable {
    let timestamp: Date
    let primaryPercent: Double?
    let primaryResetsAt: Date?
    let secondaryPercent: Double?
    let secondaryResetsAt: Date?
    let planType: String?
}

/// Parses a single line of a Codex `rollout-*.jsonl`.
/// `token_count` events yield both a `UsageEvent` (from `last_token_usage`,
/// the per-turn delta) and a `CodexRateSnapshot` (the official percentages).
enum CodexJSONLParser {

    struct Parsed {
        var event: UsageEvent?
        var snapshot: CodexRateSnapshot?
    }

    static func parse(line: String, sessionId: String) -> Parsed? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (obj["type"] as? String) == "event_msg",
              let payload = obj["payload"] as? [String: Any],
              (payload["type"] as? String) == "token_count"
        else { return nil }

        guard let tsString = obj["timestamp"] as? String,
              let timestamp = ISO8601.date(from: tsString)
        else { return nil }

        var result = Parsed()

        // Per-turn delta → UsageEvent (for cost, session, sparkline).
        if let info = payload["info"] as? [String: Any],
           let last = info["last_token_usage"] as? [String: Any] {
            let totalInput = JSON.double(last["input_tokens"])
            let cached = JSON.double(last["cached_input_tokens"])
            let output = JSON.double(last["output_tokens"])
            let reasoning = JSON.double(last["reasoning_output_tokens"])
            let uncachedInput = max(totalInput - cached, 0)

            if totalInput + output + reasoning > 0 {
                result.event = UsageEvent(
                    timestamp: timestamp,
                    sessionId: sessionId,
                    model: "codex",
                    inputTokens: uncachedInput,
                    outputTokens: output + reasoning,
                    cacheCreationTokens: 0,
                    cacheReadTokens: cached,
                    dedupeKey: "\(sessionId):\(tsString)"
                )
            }
        }

        // Official rate limits → snapshot. Codex writes `rate_limits` on every
        // token_count event but only fills `primary`/`secondary` periodically;
        // the rest are null. Only emit a snapshot that actually carries a
        // percentage, so a null event can't overwrite a good reading.
        if let limits = (obj["rate_limits"] as? [String: Any])
            ?? (payload["rate_limits"] as? [String: Any]) {
            let primary = limits["primary"] as? [String: Any]
            let secondary = limits["secondary"] as? [String: Any]
            let primaryPercent = JSON.optionalDouble(primary?["used_percent"])
            let secondaryPercent = JSON.optionalDouble(secondary?["used_percent"])
            if primaryPercent != nil || secondaryPercent != nil {
                result.snapshot = CodexRateSnapshot(
                    timestamp: timestamp,
                    primaryPercent: primaryPercent,
                    primaryResetsAt: epoch(primary?["resets_at"]),
                    secondaryPercent: secondaryPercent,
                    secondaryResetsAt: epoch(secondary?["resets_at"]),
                    planType: limits["plan_type"] as? String
                )
            }
        }

        return (result.event == nil && result.snapshot == nil) ? nil : result
    }

    private static func epoch(_ value: Any?) -> Date? {
        guard let seconds = JSON.optionalDouble(value), seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
