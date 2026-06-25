import Foundation

/// One recorded official probe reading for a tool, used to build the per-card
/// usage trend. Claude accounts have no per-hour token data — only the 5h / 7d
/// percentages each probe returns — so we persist these over time to chart them.
struct ProbeSample: Codable, Sendable {
    let t: Date       // when the sample was taken
    let h5: Double    // 5-hour utilization, 0…1+
    let d7: Double    // 7-day utilization, 0…1+
}
