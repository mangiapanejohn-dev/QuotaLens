import Foundation

/// An archived, completed quota cycle. Written when a reset is detected so we
/// never merge across resets and keep an audit trail.
struct BillingCycle: Codable, Sendable, Identifiable {
    let id: String              // tool:window:startedAt
    let toolName: String
    let windowType: WindowType
    let startedAt: Date
    let endedAt: Date           // when the reset was observed
    let peakOfficialPercent: Double?
    let peakLocalTokens: Double

    init(toolName: String, windowType: WindowType, startedAt: Date, endedAt: Date,
         peakOfficialPercent: Double?, peakLocalTokens: Double) {
        self.id = "\(toolName):\(windowType.rawValue):\(Int(startedAt.timeIntervalSince1970))"
        self.toolName = toolName
        self.windowType = windowType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.peakOfficialPercent = peakOfficialPercent
        self.peakLocalTokens = peakLocalTokens
    }
}
