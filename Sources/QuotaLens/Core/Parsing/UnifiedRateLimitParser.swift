import Foundation

/// Defensively parses Anthropic `anthropic-ratelimit-unified-*` response headers
/// into per-window `OfficialReading`s. The exact header names are undocumented
/// and may change, so this scans generically: any `…-<window>-<field>` header
/// (field ∈ limit/remaining/used/utilization/reset) is grouped by window token
/// (5h → 5-hour, 7d/week → 7-day) and turned into a 0…1 percentage.
enum UnifiedRateLimitParser {
    private static let prefix = "anthropic-ratelimit-unified-"

    static func parse(headers rawHeaders: [String: String], now: Date) -> [WindowType: OfficialReading] {
        // group field → value, keyed by window
        var fields: [WindowType: [String: String]] = [:]

        for (k, v) in rawHeaders {
            let key = k.lowercased()
            guard key.hasPrefix(prefix) else { continue }
            let remainder = String(key.dropFirst(prefix.count))     // e.g. "5h-remaining"
            guard let dash = remainder.lastIndex(of: "-") else { continue }
            let windowToken = String(remainder[..<dash])
            let field = String(remainder[remainder.index(after: dash)...])
            guard let window = window(for: windowToken) else { continue }
            fields[window, default: [:]][field] = v
        }

        var out: [WindowType: OfficialReading] = [:]
        for (window, f) in fields {
            guard let percent = percent(from: f) else { continue }
            out[window] = OfficialReading(
                percent: percent,
                limit: f["limit"].flatMap(Double.init),
                resetsAt: resetDate(f["reset"], now: now),
                source: .claudeProbe,
                fetchedAt: now
            )
        }
        return out
    }

    private static func window(for token: String) -> WindowType? {
        if token.contains("5h") || token.contains("5-h") || token.contains("five") { return .fiveHour }
        if token.contains("7d") || token.contains("7-d") || token.contains("week") || token.contains("seven") { return .sevenDay }
        return nil
    }

    private static func percent(from f: [String: String]) -> Double? {
        if let limit = f["limit"].flatMap(Double.init), limit > 0,
           let remaining = f["remaining"].flatMap(Double.init) {
            return min(max((limit - remaining) / limit, 0), 2)
        }
        for key in ["used", "utilization", "used_percent"] {
            if let raw = f[key].flatMap(Double.init) {
                return raw > 1.5 ? raw / 100 : raw   // accept 0..1 or 0..100
            }
        }
        return nil
    }

    private static func resetDate(_ raw: String?, now: Date) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let num = Double(raw) {
            if num > 1_000_000_000 { return Date(timeIntervalSince1970: num) } // epoch seconds
            if num > 0 { return now.addingTimeInterval(num) }                   // seconds-from-now
            return nil
        }
        return ISO8601.date(from: raw)   // ISO timestamp
    }
}
