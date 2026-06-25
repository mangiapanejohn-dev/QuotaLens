import Foundation

/// Where an authoritative reading came from.
enum OfficialSourceKind: String, Codable, Sendable {
    case codexFile      // parsed from Codex rollout rate_limits (no network)
    case claudeProbe    // OAuth-probed anthropic-ratelimit-unified headers
}

/// An authoritative usage reading for one tool × one window.
/// `percent` is a 0…1 ratio (server truth). This always overrides the local
/// estimate when present — official data is truth.
struct OfficialReading: Codable, Sendable {
    var percent: Double          // 0…1
    var limit: Double?           // tokens, when the source exposes it
    var resetsAt: Date?
    var source: OfficialSourceKind
    var fetchedAt: Date
    var stale: Bool              // last-known value kept after a failed refresh

    init(percent: Double, limit: Double? = nil, resetsAt: Date? = nil,
         source: OfficialSourceKind, fetchedAt: Date, stale: Bool = false) {
        self.percent = percent
        self.limit = limit
        self.resetsAt = resetsAt
        self.source = source
        self.fetchedAt = fetchedAt
        self.stale = stale
    }
}
