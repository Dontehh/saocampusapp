//
//  AuthService.swift
//  Campus
//
//  Microsoft (Azure AD / Entra) authentication shim for the
//  Al Akhawayn University tenant. CampusPulse is restricted to the
//  university domain — only @aui.ma accounts can sign in.
//
//  PRODUCTION INTEGRATION
//  ----------------------
//  Replace the body of `signInWithMicrosoft(in:)` with a call to MSAL:
//    1. Add the MSAL Swift Package:
//         https://github.com/AzureAD/microsoft-authentication-library-for-objc
//    2. Register CampusPulse in the AUI Azure tenant and pull in the
//       clientId + redirect URI.
//    3. Configure URL schemes in Info.plist (msauth.<bundle-id>).
//    4. Call `MSALPublicClientApplication.acquireToken(...)` and feed the
//       returned `MSALResult.account.username` into `complete(with:)`.
//  The rest of the app already routes by `currentUser.role`, so swapping
//  the implementation is a localized change.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthService: ObservableObject {

    /// Required email domain for every sign-in. The university operates a
    /// single Microsoft tenant for both students and staff under this
    /// hostname, so anything else is rejected outright.
    static let requiredDomain = "aui.ma"

    @Published var currentUser: AppUser?
    @Published var loginError:  String?
    @Published var isAuthenticating = false

    // MARK: - Entry point used by the UI

    /// Simulates the MSAL acquireToken flow. In production this is
    /// replaced with a real Azure AD round-trip; for the prototype we
    /// accept any pre-seeded @aui.ma account.
    func signInWithMicrosoft(email: String, in store: DataStore) {
        let normalized = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard validate(email: normalized) else { return }

        isAuthenticating = true
        // Simulated round-trip delay so the UI affordances actually animate.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            defer { self.isAuthenticating = false }
            self.complete(authenticatedEmail: normalized, in: store)
        }
    }

    /// Hook for the production MSAL callback. Once you have a verified
    /// token + account, hand the upn over to this method and the rest
    /// of the app picks up seamlessly.
    func complete(authenticatedEmail email: String, in store: DataStore) {
        let normalized = email.lowercased()
        guard validate(email: normalized) else { return }

        if let match = store.users.first(where: { $0.email.lowercased() == normalized }) {
            currentUser = match
            loginError  = nil
        } else {
            loginError = "Account \(normalized) isn't registered with SAO. Ask staff to add you to the roster."
        }
    }

    func signOut() {
        currentUser      = nil
        loginError       = nil
        isAuthenticating = false
        // For production MSAL you'd also call
        // `MSALPublicClientApplication.remove(account:)` here.
    }

    // MARK: - Validation

    @discardableResult
    private func validate(email: String) -> Bool {
        guard !email.isEmpty else {
            loginError = "Please enter your AUI email."
            return false
        }
        guard email.hasSuffix("@\(Self.requiredDomain)") else {
            loginError = "CampusPulse is restricted to @\(Self.requiredDomain) accounts."
            return false
        }
        guard email.contains("@"),
              email.split(separator: "@").count == 2,
              let local = email.split(separator: "@").first,
              !local.isEmpty
        else {
            loginError = "That doesn't look like a valid AUI email."
            return false
        }
        loginError = nil
        return true
    }
}
