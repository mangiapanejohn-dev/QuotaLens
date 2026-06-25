import Foundation

/// Parses a single line of a Claude Code session `.jsonl` into a `UsageEvent`.
/// Only `type == "assistant"` lines carrying `message.usage` produce an event.
enum ClaudeJSONLParser {

    static func parse(line: String) -> UsageEvent? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (obj["type"] as? String) == "assistant",
              let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any]
        else { return nil }

        guard let tsString = obj["timestamp"] as? String,
              let timestamp = ISO8601.date(from: tsString)
        else { return nil }

        let sessionId = (obj["sessionId"] as? String) ?? "unknown"
        let model = (message["model"] as? String) ?? "claude"

        let input = JSON.double(usage["input_tokens"])
        let output = JSON.double(usage["output_tokens"])
        let cacheCreate = JSON.double(usage["cache_creation_input_tokens"])
        let cacheRead = JSON.double(usage["cache_read_input_tokens"])

        // Skip "empty" usage rows (e.g. stop messages) so they don't pollute counts.
        if input + output + cacheCreate + cacheRead == 0 { return nil }

        let requestId = (obj["requestId"] as? String) ?? ""
        let messageId = (message["id"] as? String) ?? ""
        let dedupeKey = requestId.isEmpty && messageId.isEmpty
            ? "\(sessionId):\(tsString)"
            : "\(requestId):\(messageId)"

        return UsageEvent(
            timestamp: timestamp,
            sessionId: sessionId,
            model: model,
            inputTokens: input,
            outputTokens: output,
            cacheCreationTokens: cacheCreate,
            cacheReadTokens: cacheRead,
            dedupeKey: dedupeKey
        )
    }
}

/// Tiny helpers for pulling numbers out of `JSONSerialization` output.
enum JSON {
    static func double(_ value: Any?) -> Double {
        switch value {
        case let n as NSNumber: return n.doubleValue
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let s as String: return Double(s) ?? 0
        default: return 0
        }
    }

    static func optionalDouble(_ value: Any?) -> Double? {
        switch value {
        case let n as NSNumber: return n.doubleValue
        case let d as Double: return d
        case let i as Int: return Double(i)
        default: return nil
        }
    }
}
