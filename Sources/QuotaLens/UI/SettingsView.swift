import SwiftUI

/// Grouped settings, styled like macOS System Settings cards. The signature is
/// the unified "Sources" list: Codex and each Claude account share one polished
/// row treatment; only Claude rows carry a token (Codex reads locally).
struct SettingsView: View {
    @EnvironmentObject var store: UsageStore
    @EnvironmentObject var settings: Settings
    @Binding var showSettings: Bool

    @State private var addingAccount = false
    @State private var newName = ""
    @State private var newToken = ""
    @State private var editingTokenID: String?
    @State private var tokenDraft = ""

    private let maxCards = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                CircleIconButton(systemName: "chevron.left", size: 13) { showSettings = false }
                Text("Settings")
                    .font(.ql(16, .bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 12) {
                    sourcesCard
                    refreshCard
                    windowCard
                    diagnosticsCard
                    notificationsCard
                    startupCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.never)
        }
    }

    // MARK: - Sources

    private var totalCards: Int { store.fixedTools.count + settings.claudeAccounts.count }
    private var atCap: Bool { totalCards >= maxCards }

    private var sourcesCard: some View {
        card {
            HStack {
                Eyebrow(text: "Sources")
                Spacer()
                Text("\(totalCards)/\(maxCards)")
                    .font(.qlMono(9, .medium))
                    .foregroundStyle(Palette.textTertiary)
            }

            ForEach(settings.claudeAccounts) { account in
                claudeRow(account)
            }
            ForEach(store.fixedTools, id: \.name) { tool in
                codexRow(name: tool.name, label: tool.label)
            }

            Rectangle().fill(Palette.stroke).frame(height: 1).padding(.vertical, 2)
            addAccountSection
        }
    }

    private func claudeRow(_ account: ClaudeAccount) -> some View {
        let expired = store.snapshots.first { $0.toolName == account.toolName }?.expired ?? false
        let editing = editingTokenID == account.id
        return VStack(alignment: .leading, spacing: 0) {
            sourceRow(
                tint: Palette.toolColor(account.toolName),
                name: account.name,
                subtitle: editing ? "Paste a fresh token to replace" : "Official · token",
                pill: expired ? ("expired", Palette.danger) : ("active", Palette.brand),
                toolName: account.toolName
            ) {
                CircleIconButton(systemName: editing ? "xmark" : "key.horizontal", size: 11) {
                    withAnimation(.qlSmooth) {
                        if editing { editingTokenID = nil } else { editingTokenID = account.id; tokenDraft = "" }
                    }
                }
                CircleIconButton(systemName: "trash", size: 11) {
                    withAnimation(.qlSmooth) { settings.removeAccount(account) }
                }
            }

            if editing {
                HStack(spacing: 8) {
                    SecureField("paste from: claude setup-token", text: $tokenDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.qlMono(10))
                    pillButton("Save", filled: true, enabled: !tokenDraft.trimmed.isEmpty) {
                        saveToken(for: account)
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 41)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func codexRow(name: String, label: String) -> some View {
        sourceRow(
            tint: Palette.toolColor(name),
            name: label,
            subtitle: "Local · no network",
            pill: ("local", Palette.textTertiary),
            toolName: name
        ) { EmptyView() }
    }

    /// One source row: glyph tile · name + subtitle + status pill · actions · enable.
    private func sourceRow<Actions: View>(
        tint: Color, name: String, subtitle: String,
        pill: (text: String, color: Color), toolName: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.16))
                .frame(width: 30, height: 30)
                .overlay(BrandLogo(toolName: toolName, size: 15, tint: tint))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(.ql(12.5, .semibold)).foregroundStyle(Palette.textPrimary)
                    statusPill(pill.text, pill.color)
                }
                Text(subtitle).font(.ql(9.5)).foregroundStyle(Palette.textTertiary)
            }
            Spacer(minLength: 6)
            actions()
            Toggle("", isOn: enabledBinding(for: toolName))
                .toggleStyle(.switch).tint(Palette.brand).labelsHidden()
                .scaleEffect(0.85)
        }
        .padding(.vertical, 4)
    }

    private func statusPill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.ql(8.5, .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 1.5)
            .background(Capsule().fill(color.opacity(0.16)))
    }

    @ViewBuilder
    private var addAccountSection: some View {
        if atCap {
            Text("Showing the max of \(maxCards) sources. Remove one to add another.")
                .font(.ql(9.5)).foregroundStyle(Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if addingAccount {
            VStack(spacing: 8) {
                TextField("Name (e.g. Pro, Max5x)", text: $newName)
                    .textFieldStyle(.roundedBorder).font(.ql(11))
                SecureField("paste from: claude setup-token", text: $newToken)
                    .textFieldStyle(.roundedBorder).font(.qlMono(10))
                HStack {
                    pillButton("Cancel", filled: false, enabled: true) {
                        withAnimation(.qlSmooth) { addingAccount = false; newName = ""; newToken = "" }
                    }
                    Spacer()
                    pillButton("Add account", filled: true,
                               enabled: !newName.trimmed.isEmpty && !newToken.trimmed.isEmpty) {
                        addAccount()
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            Button {
                withAnimation(.qlSmooth) { addingAccount = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 12, weight: .semibold))
                    Text("Add Claude account").font(.ql(11.5, .semibold))
                }
                .foregroundStyle(Palette.brand)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Other cards

    private var refreshCard: some View {
        card {
            Eyebrow(text: "Refresh interval")
            HStack(spacing: 10) {
                Slider(value: $settings.refreshInterval, in: 2...60, step: 1).tint(Palette.brand)
                Text("\(Int(settings.refreshInterval))s")
                    .font(.qlMono(11)).foregroundStyle(Palette.textSecondary)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    private var windowCard: some View {
        card {
            Eyebrow(text: "5-hour window")
            Picker("", selection: $settings.fiveHourMode) {
                ForEach(FiveHourMode.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
        }
    }

    private var diagnosticsCard: some View {
        card {
            Eyebrow(text: "Diagnostics")
            toggle("Show local − official delta", binding: $settings.showDiagnostics)
            Text("Claude accounts read official 5h / 7d limits via your token. Codex reads locally with no network.")
                .font(.ql(9)).foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notificationsCard: some View {
        card {
            Eyebrow(text: "Notifications")
            toggle("Threshold alerts (80 / 90 / 100%)", binding: $settings.notificationsEnabled)
        }
    }

    private var startupCard: some View {
        card {
            Eyebrow(text: "Startup")
            toggle("Launch at login", binding: $settings.launchAtLogin)
        }
    }

    // MARK: - Actions

    private func addAccount() {
        let name = newName.trimmed, token = newToken.trimmed
        guard !name.isEmpty, !token.isEmpty, !atCap else { return }
        settings.addAccount(name: name, token: token)
        withAnimation(.qlSmooth) { addingAccount = false; newName = ""; newToken = "" }
    }

    private func saveToken(for account: ClaudeAccount) {
        let token = tokenDraft.trimmed
        guard !token.isEmpty,
              let i = settings.claudeAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        settings.claudeAccounts[i].token = token
        withAnimation(.qlSmooth) { editingTokenID = nil; tokenDraft = "" }
    }

    // MARK: - Building blocks

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile(16)
    }

    private func toggle(_ label: String, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(label).font(.ql(12)).foregroundStyle(Palette.textPrimary)
        }
        .toggleStyle(.switch).tint(Palette.brand)
    }

    private func pillButton(_ title: String, filled: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.ql(10.5, .semibold))
                .foregroundStyle(filled ? Palette.ink : Palette.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(filled ? Palette.brand : Palette.tileRaised))
                .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func enabledBinding(for tool: String) -> Binding<Bool> {
        Binding(get: { settings.isEnabled(tool) }, set: { settings.setEnabled($0, for: tool) })
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
