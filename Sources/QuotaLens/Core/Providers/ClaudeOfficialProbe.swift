import Foundation

/// Obtains one Claude account's authoritative subscription usage by probing the
/// API with a pasted `setup-token` and reading `anthropic-ratelimit-unified-*`
/// response headers. Claude does not persist these anywhere, so a probe is the
/// only way. One instance per account.
///
/// Safety: read-only, fails closed (any error → empty/stale, never crashes),
/// throttled, and never logs the token. A pasted token has no refresh token, so
/// on 401/403 it is reported `expired` for the UI to surface (re-paste needed).
actor ClaudeOfficialProbe: OfficialSource {
    nonisolated let toolName: String

    private let token: String
    private var lastProbe: Date?
    private var lastReadings: [WindowType: OfficialReading] = [:]
    private var expiredFlag = false
    private let session: URLSession

    // A current model the subscription can access; only used to elicit the
    // unified rate-limit headers (which appear on /v1/messages).
    private let model = "claude-haiku-4-5-20251001"
    private let host = "https://api.anthropic.com"

    init(toolName: String, token: String) {
        self.toolName = toolName
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 12
        self.session = URLSession(configuration: cfg)
    }

    /// Whether the last probe failed auth (expired/invalid token).
    func isExpired() -> Bool { expiredFlag }

    func officialReadings(now: Date, latestActivity: Date?) async -> [WindowType: OfficialReading] {
        guard !token.isEmpty else { return [:] }
        if shouldProbe(now: now) { await probe(now: now) }
        return lastReadings
    }

    // MARK: - Throttle

    /// Probe on cold start, then at most every 5 minutes. Pasted-token accounts
    /// have no local activity signal, so the cadence is fixed (not activity-gated).
    private func shouldProbe(now: Date) -> Bool {
        guard let last = lastProbe else { return true }
        return now.timeIntervalSince(last) >= 300
    }

    // MARK: - Probe

    private func probe(now: Date) async {
        let (readings, status) = await fetch(token: token, now: now)
        lastProbe = now

        if let readings, !readings.isEmpty {
            lastReadings = readings
            expiredFlag = false
            return
        }
        if status == 401 || status == 403 {
            expiredFlag = true
            lastReadings = [:]
            return
        }
        markStale()   // transient failure: keep last readings, flag stale
    }

    private func markStale() {
        lastReadings = lastReadings.mapValues {
            OfficialReading(percent: $0.percent, limit: $0.limit, resetsAt: $0.resetsAt,
                            source: $0.source, fetchedAt: $0.fetchedAt, stale: true)
        }
    }

    /// Returns parsed readings and the HTTP status, so the caller can tell an
    /// auth failure (401/403 → expired) from a transient/network error.
    private func fetch(token: String, now: Date) async -> (readings: [WindowType: OfficialReading]?, status: Int?) {
        guard let url = URL(string: host + "/v1/messages") else { return (nil, nil) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "."]],
            "max_tokens": 1,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return (nil, nil) }

        var headers: [String: String] = [:]
        for (k, v) in http.allHeaderFields {
            if let ks = k as? String, let vs = v as? String { headers[ks] = vs }
        }
        let readings = UnifiedRateLimitParser.parse(headers: headers, now: now)
        return (readings.isEmpty ? nil : readings, http.statusCode)
    }
}
