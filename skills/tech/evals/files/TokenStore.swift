import Foundation

enum TokenStoreError: Error, Equatable {
    case notFound(account: String)
    case expired(account: String)
}

/// Caches access tokens per account; asks the refresher for a new one when a token expires.
actor TokenStore {
    struct Token: Sendable, Equatable {
        let value: String
        let expiresAt: Date
    }

    private var tokens: [String: Token] = [:]
    private let now: @Sendable () -> Date
    private let refresh: @Sendable (String) async throws -> Token

    init(
        now: @escaping @Sendable () -> Date = Date.init,
        refresh: @escaping @Sendable (String) async throws -> Token
    ) {
        self.now = now
        self.refresh = refresh
    }

    func store(_ token: Token, for account: String) {
        tokens[account] = token
    }

    /// Returns a valid token, refreshing an expired one. Throws notFound for an unknown account.
    func token(for account: String) async throws -> Token {
        guard let token = tokens[account] else {
            throw TokenStoreError.notFound(account: account)
        }
        if token.expiresAt > now() {
            return token
        }
        let fresh = try await refresh(account)
        tokens[account] = fresh
        return fresh
    }
}
