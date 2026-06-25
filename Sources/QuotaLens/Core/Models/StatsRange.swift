import Foundation

/// Chart/aggregation resolution. Short spans render hourly for a smooth curve;
/// longer spans roll up to daily.
enum StatsGranularity: Sendable { case hour, day }

/// A selectable time window for the statistics window. Presets are rolling
/// (anchored to "now"); `custom` is an inclusive day range the user picks.
enum StatsRange: Equatable, Hashable {
    case today, last3, last7, last30, all
    case custom(Date, Date)

    static let presets: [StatsRange] = [.today, .last3, .last7, .last30, .all]

    var label: String {
        switch self {
        case .today:  return "Today"
        case .last3:  return "3 days"
        case .last7:  return "7 days"
        case .last30: return "30 days"
        case .all:    return "All"
        case .custom: return "Custom"
        }
    }

    var isCustom: Bool { if case .custom = self { return true } else { return false } }

    /// The concrete window, or nil for all-time (no filtering).
    func interval(now: Date, calendar: Calendar = .current) -> DateInterval? {
        let sod = calendar.startOfDay(for: now)
        func daysBack(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: sod) ?? sod }
        switch self {
        case .today:  return DateInterval(start: sod, end: now)
        case .last3:  return DateInterval(start: daysBack(2), end: now)
        case .last7:  return DateInterval(start: daysBack(6), end: now)
        case .last30: return DateInterval(start: daysBack(29), end: now)
        case .all:    return nil
        case .custom(let a, let b):
            let start = calendar.startOfDay(for: min(a, b))
            let endDay = calendar.startOfDay(for: max(a, b))
            let end = (calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay).addingTimeInterval(-1)
            return DateInterval(start: start, end: end)
        }
    }

    /// Hourly for spans up to ~3 days, daily beyond (and for all-time).
    func granularity(now: Date) -> StatsGranularity {
        guard let iv = interval(now: now) else { return .day }
        return iv.duration <= 3.5 * 86_400 ? .hour : .day
    }
}
