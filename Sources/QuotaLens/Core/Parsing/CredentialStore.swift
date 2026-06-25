import Foundation

/// Read/write access to the Claude Code OAuth credential.
/// We refresh the access token using the stored refresh token and write the
/// rotated tokens back atomically (with a backup, preserving 0600 perms) so
/// Claude Code stays in sync. We never log token values.
struct ClaudeCredential: Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    var isExpired: Bool { expiresAt <= Date() }
    /// Refresh slightly ahead of expiry to avoid races.
    var needsRefresh: Bool { expiresAt <= Date().addingTimeInterval(120) }
}

enum CredentialStore {
    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
    }

    static func load() -> ClaudeCredential? {
        guard let data = try? Data(contentsOf: fileURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return nil }

        let refresh = (oauth["refreshToken"] as? String) ?? ""
        let expiresMs = JSON.double(oauth["expiresAt"])
        let expiresAt = expiresMs > 0
            ? Date(timeIntervalSince1970: expiresMs / 1000)
            : .distantPast
        return ClaudeCredential(accessToken: token, refreshToken: refresh, expiresAt: expiresAt)
    }

    /// Update only the three OAuth fields, preserving every other key, and
    /// re-apply 0600 permissions. Backs up before writing.
    static func write(accessToken: String, refreshToken: String, expiresAt: Date) {
        guard let data = try? Data(contentsOf: fileURL),
              var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var oauth = obj["claudeAiOauth"] as? [String: Any]
        else { return }

        oauth["accessToken"] = accessToken
        oauth["refreshToken"] = refreshToken
        oauth["expiresAt"] = Int(expiresAt.timeIntervalSince1970 * 1000)
        obj["claudeAiOauth"] = oauth

        guard let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted])
        else { return }

        // Backup the original once per write, then atomic replace. Keep both at 0600.
        let backup = fileURL.appendingPathExtension("quotalens.bak")
        try? data.write(to: backup)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        guard (try? out.write(to: fileURL, options: .atomic)) != nil else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
