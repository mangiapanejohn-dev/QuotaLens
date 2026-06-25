import Foundation

/// A source of authoritative usage readings for a tool. Separate from
/// `UsageProvider` (local tracking) so a tool can have one, both, or neither.
protocol OfficialSource: Sendable {
    var toolName: String { get }

    /// Latest authoritative readings keyed by window. Empty when unavailable.
    /// `latestActivity` lets the source decide whether a network probe is due.
    func officialReadings(now: Date, latestActivity: Date?) async -> [WindowType: OfficialReading]
}
