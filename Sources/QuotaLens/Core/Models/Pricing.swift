import Foundation

/// Approximate model pricing in USD per million tokens. Used only for the
/// secondary "$ spent" figure, so rough numbers are acceptable and the table
/// degrades gracefully (unknown models fall back to a default rate).
enum Pricing {
    struct Rate: Sendable {
        var input: Double          // $ / 1M input tokens
        var output: Double         // $ / 1M output tokens
        var cacheWrite: Double     // $ / 1M cache-creation tokens
        var cacheRead: Double      // $ / 1M cache-read tokens
    }

    /// Matched by substring against the model id (longest match wins).
    private static let table: [(key: String, rate: Rate)] = [
        ("claude-opus-4",   Rate(input: 15, output: 75, cacheWrite: 18.75, cacheRead: 1.5)),
        ("claude-opus",     Rate(input: 15, output: 75, cacheWrite: 18.75, cacheRead: 1.5)),
        ("claude-sonnet-4", Rate(input: 3,  output: 15, cacheWrite: 3.75,  cacheRead: 0.30)),
        ("claude-sonnet",   Rate(input: 3,  output: 15, cacheWrite: 3.75,  cacheRead: 0.30)),
        ("claude-haiku",    Rate(input: 1,  output: 5,  cacheWrite: 1.25,  cacheRead: 0.10)),
        ("gpt-5",           Rate(input: 1.25, output: 10, cacheWrite: 1.25, cacheRead: 0.125)),
        ("o4",              Rate(input: 1.10, output: 4.40, cacheWrite: 1.10, cacheRead: 0.275)),
        ("codex",           Rate(input: 1.25, output: 10, cacheWrite: 1.25, cacheRead: 0.125)),
    ]

    private static let fallback = Rate(input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.30)

    static func rate(for model: String) -> Rate {
        let lower = model.lowercased()
        let match = table
            .filter { lower.contains($0.key) }
            .max(by: { $0.key.count < $1.key.count })
        return match?.rate ?? fallback
    }

    static func cost(for event: UsageEvent) -> Double {
        let r = rate(for: event.model)
        return event.inputTokens / 1_000_000 * r.input
            + event.outputTokens / 1_000_000 * r.output
            + event.cacheCreationTokens / 1_000_000 * r.cacheWrite
            + event.cacheReadTokens / 1_000_000 * r.cacheRead
    }
}
