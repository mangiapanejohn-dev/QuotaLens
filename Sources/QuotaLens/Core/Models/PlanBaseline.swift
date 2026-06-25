import Foundation

/// Subscription plans for which we keep an estimated token baseline.
/// Anthropic does not publish hard token limits, so these are heuristic
/// estimates that the user can override in Settings.
enum SubscriptionPlan: String, CaseIterable, Codable, Sendable, Identifiable {
    case claudePro = "Claude Pro"
    case claudeMax5 = "Claude Max 5x"
    case claudeMax20 = "Claude Max 20x"

    var id: String { rawValue }
}

/// Token baselines used as the denominator for self-computed percentages.
struct PlanBaseline: Codable, Sendable {
    var fiveHour: Double
    var sevenDay: Double

    /// Default estimates (overridable). Numbers are intentionally round —
    /// they are reference budgets, not official limits.
    static func defaults(for plan: SubscriptionPlan) -> PlanBaseline {
        switch plan {
        case .claudePro:
            return PlanBaseline(fiveHour: 7_000_000, sevenDay: 50_000_000)
        case .claudeMax5:
            return PlanBaseline(fiveHour: 35_000_000, sevenDay: 250_000_000)
        case .claudeMax20:
            return PlanBaseline(fiveHour: 140_000_000, sevenDay: 1_000_000_000)
        }
    }
}
