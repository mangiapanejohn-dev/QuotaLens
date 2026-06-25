import Foundation

/// A detected quota reset, surfaced on the timeline.
struct ResetMarker: Codable, Sendable, Identifiable {
    let toolName: String
    let windowType: WindowType
    let at: Date
    var id: String { "\(toolName):\(windowType.rawValue):\(Int(at.timeIntervalSince1970))" }
}

/// Detects quota resets from successive official readings and archives the
/// completed cycle instead of merging across the reset. A reset fires when the
/// official percent drops, the limit changes, or the reset timestamp advances.
@MainActor
final class ResetDetectionService {
    private struct CycleState {
        var last: OfficialReading
        var startedAt: Date
        var peakPercent: Double
        var peakLocalTokens: Double
    }

    private var states: [String: CycleState] = [:]
    private var markers: [ResetMarker] = []
    private let persistence: PersistenceService

    init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    /// Feed the latest snapshots; returns nothing but updates internal markers
    /// and archives any cycles that just ended.
    func observe(snapshots: [ToolSnapshot], now: Date) {
        for snapshot in snapshots {
            for window in [WindowType.fiveHour, .sevenDay] {
                guard let usage = snapshot.usage(window),
                      let official = usage.official, !official.stale else { continue }
                evaluate(tool: snapshot.toolName, window: window,
                         official: official, localTokens: usage.usedTokens, now: now)
            }
        }
        trimMarkers(now: now)
    }

    /// Reset markers for one tool within the last `seconds`.
    func markers(for toolName: String, within seconds: TimeInterval, now: Date) -> [Date] {
        markers
            .filter { $0.toolName == toolName && now.timeIntervalSince($0.at) <= seconds }
            .map(\.at)
    }

    // MARK: - Detection

    private func evaluate(tool: String, window: WindowType, official: OfficialReading, localTokens: Double, now: Date) {
        let key = "\(tool):\(window.rawValue)"
        guard let state = states[key] else {
            states[key] = CycleState(last: official, startedAt: now,
                                     peakPercent: official.percent, peakLocalTokens: localTokens)
            return
        }

        if isReset(previous: state.last, current: official) {
            archive(tool: tool, window: window, state: state, endedAt: now)
            markers.append(ResetMarker(toolName: tool, windowType: window, at: now))
            states[key] = CycleState(last: official, startedAt: now,
                                     peakPercent: official.percent, peakLocalTokens: localTokens)
        } else {
            states[key] = CycleState(
                last: official,
                startedAt: state.startedAt,
                peakPercent: max(state.peakPercent, official.percent),
                peakLocalTokens: max(state.peakLocalTokens, localTokens)
            )
        }
    }

    private func isReset(previous: OfficialReading, current: OfficialReading) -> Bool {
        if current.percent < previous.percent - 0.02 { return true }          // official decreased
        if let a = current.limit, let b = previous.limit, a != b { return true } // limit changed
        if let a = current.resetsAt, let b = previous.resetsAt,
           a > b.addingTimeInterval(60) { return true }                       // reset window advanced
        return false
    }

    private func archive(tool: String, window: WindowType, state: CycleState, endedAt: Date) {
        let cycle = BillingCycle(
            toolName: tool, windowType: window,
            startedAt: state.startedAt, endedAt: endedAt,
            peakOfficialPercent: state.peakPercent, peakLocalTokens: state.peakLocalTokens)
        persistence.appendCycle(cycle)
    }

    private func trimMarkers(now: Date) {
        let cutoff = now.addingTimeInterval(-7 * 24 * 3600)
        markers = markers.filter { $0.at >= cutoff }.suffix(100).map { $0 }
    }
}
