import Foundation

/// A Claude subscription account tracked via a pasted `claude setup-token`.
/// Each account is probed independently and renders as its own card.
/// `token` is the OAuth access token; it cannot be refreshed (no refresh token),
/// so it expires and must be re-pasted — surfaced via a notification + card flag.
struct ClaudeAccount: Identifiable, Codable, Equatable {
    let id: String          // stable UUID string, minted once on creation
    var name: String        // user-given label, e.g. "Pro" / "Max5x"
    var token: String       // pasted setup-token (access token)

    /// Tool identity used across snapshots, settings toggles and persistence.
    var toolName: String { "claude-\(id)" }

    init(id: String = UUID().uuidString, name: String, token: String) {
        self.id = id
        self.name = name
        self.token = token
    }
}
