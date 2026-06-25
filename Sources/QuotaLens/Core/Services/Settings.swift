import Foundation
import Combine

/// User-facing settings, persisted to `UserDefaults`.
@MainActor
final class Settings: ObservableObject {
    private let defaults: UserDefaults

    @Published var refreshInterval: Double { didSet { defaults.set(refreshInterval, forKey: K.refresh) } }
    @Published var fiveHourMode: FiveHourMode { didSet { defaults.set(fiveHourMode.rawValue, forKey: K.mode) } }
    @Published var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: K.notify) } }
    @Published var timelineHours: Int { didSet { defaults.set(timelineHours, forKey: K.timeline) } }

    /// Launch at login (registers the app bundle as a login item).
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: K.login); LoginItem.set(launchAtLogin) }
    }

    /// Show the Local − Official delta diagnostics section.
    @Published var showDiagnostics: Bool { didSet { defaults.set(showDiagnostics, forKey: K.diag) } }

    /// Claude accounts, each probed via its own pasted `setup-token`.
    @Published var claudeAccounts: [ClaudeAccount] { didSet { saveAccounts() } }

    @Published var disabledTools: Set<String> {
        didSet { defaults.set(Array(disabledTools), forKey: K.disabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.refreshInterval = defaults.object(forKey: K.refresh) as? Double ?? 5
        self.fiveHourMode = FiveHourMode(rawValue: defaults.string(forKey: K.mode) ?? "") ?? .block
        self.notificationsEnabled = defaults.object(forKey: K.notify) as? Bool ?? true
        self.timelineHours = defaults.object(forKey: K.timeline) as? Int ?? 24
        self.showDiagnostics = defaults.object(forKey: K.diag) as? Bool ?? false
        self.disabledTools = Set(defaults.stringArray(forKey: K.disabled) ?? [])
        self.claudeAccounts = Self.loadAccounts(from: defaults)
        self.launchAtLogin = defaults.bool(forKey: K.login)
    }

    /// Reconcile the actual login-item registration with the saved preference
    /// (call once at launch).
    func syncLoginItem() { LoginItem.set(launchAtLogin) }

    /// Claude baselines are no longer user-configured (cards are official-only);
    /// a fixed reference baseline is kept only for the orphaned local provider.
    var providerConfig: ProviderConfig {
        ProviderConfig(
            fiveHourMode: fiveHourMode,
            claudeBaseline: PlanBaseline.defaults(for: .claudeMax5)
        )
    }

    func isEnabled(_ tool: String) -> Bool { !disabledTools.contains(tool) }

    func setEnabled(_ enabled: Bool, for tool: String) {
        if enabled { disabledTools.remove(tool) } else { disabledTools.insert(tool) }
    }

    // MARK: - Accounts

    func addAccount(name: String, token: String) {
        claudeAccounts.append(ClaudeAccount(name: name, token: token))
    }

    func removeAccount(_ account: ClaudeAccount) {
        claudeAccounts.removeAll { $0.id == account.id }
        disabledTools.remove(account.toolName)
    }

    private func saveAccounts() {
        guard let data = try? JSONEncoder().encode(claudeAccounts) else { return }
        defaults.set(data, forKey: K.accounts)
    }

    private static func loadAccounts(from defaults: UserDefaults) -> [ClaudeAccount] {
        guard let data = defaults.data(forKey: K.accounts),
              let accounts = try? JSONDecoder().decode([ClaudeAccount].self, from: data)
        else { return [] }
        return accounts
    }

    private enum K {
        static let refresh = "refreshInterval"
        static let mode = "fiveHourMode"
        static let notify = "notificationsEnabled"
        static let timeline = "timelineHours"
        static let disabled = "disabledTools"
        static let diag = "showDiagnostics"
        static let accounts = "claudeAccounts"
        static let login = "launchAtLogin"
    }
}
