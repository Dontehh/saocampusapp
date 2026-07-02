//
//  LoginView.swift
//  Campus
//
//  Microsoft SSO entry restricted to the @aui.ma university domain.
//  This view talks to AuthService.signInWithMicrosoft(...); replace
//  that implementation with the real MSAL acquireToken to ship.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth:  AuthService
    @EnvironmentObject private var store: DataStore

    @State private var email = ""

    var body: some View {
        GlassScene {
            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 40)
                    branding
                    formCard
                    demoAccountsCard
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
        }
        .animation(AppMotion.smooth, value: auth.isAuthenticating)
        .animation(AppMotion.smooth, value: auth.loginError)
    }

    // MARK: - Branding

    private var branding: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Theme.accent.opacity(0.85),
                                                Color(red: 0.85, green: 0.30, blue: 0.05)],
                                       startPoint: .topLeading,
                                       endPoint:   .bottomTrailing)
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Theme.accent.opacity(0.35),
                            radius: 22, x: 0, y: 12)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("CampusPulse")
                .font(.system(size: 38, weight: .bold, design: .rounded))
            Text("SAO Event Analytics · Al Akhawayn University")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .glassCard(radius: 12)
        }
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sign in with your university account")
                    .font(.subheadline.weight(.semibold))
                Text("CampusPulse is restricted to @aui.ma Microsoft accounts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 18)
                TextField("you@aui.ma", text: $email)
                    .iosAutocap()
                    .emailKeyboard()
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(signIn)
                    .disabled(auth.isAuthenticating)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .softCard(radius: 14)

            if let err = auth.loginError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(err)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: signIn) {
                HStack(spacing: 12) {
                    if auth.isAuthenticating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        MicrosoftMarkView()
                            .frame(width: 18, height: 18)
                    }
                    Text(auth.isAuthenticating
                         ? "Signing in…"
                         : "Continue with Microsoft")
                }
            }
            .buttonStyle(.glassPrimary)
            .disabled(auth.isAuthenticating || email.isEmpty)
            .padding(.top, 4)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.secondary)
                Text("Authentication routed through aui.ma · MSAL")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .glassCard(tint: Theme.accent.opacity(0.20), radius: 26)
    }

    // MARK: - Demo accounts

    private var demoAccountsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Demo Accounts (tap to auto-fill)",
                  systemImage: "info.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(store.demoAccounts, id: \.email) { account in
                    Button {
                        email = account.email
                    } label: {
                        row(account.email, account.role)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Any other @aui.ma email signs in as a general student.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(radius: 18)
    }

    private func row(_ email: String, _ role: String) -> some View {
        HStack {
            Text(email)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
            Spacer()
            Text(role)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func signIn() {
        auth.signInWithMicrosoft(email: email, in: store)
    }
}

// MARK: - Microsoft logo mark

/// Four-quadrant brand mark used on the SSO button.
private struct MicrosoftMarkView: View {
    var body: some View {
        GeometryReader { geo in
            let gap = geo.size.width * 0.08
            let tile = (geo.size.width - gap) / 2
            ZStack {
                tileRect(x: 0,             y: 0,             size: tile,
                         color: Color(red: 0.95, green: 0.32, blue: 0.21))
                tileRect(x: tile + gap,    y: 0,             size: tile,
                         color: Color(red: 0.49, green: 0.74, blue: 0.27))
                tileRect(x: 0,             y: tile + gap,    size: tile,
                         color: Color(red: 0.00, green: 0.65, blue: 0.93))
                tileRect(x: tile + gap,    y: tile + gap,    size: tile,
                         color: Color(red: 1.00, green: 0.72, blue: 0.00))
            }
        }
    }

    private func tileRect(x: CGFloat, y: CGFloat,
                          size: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    LoginView()
        .environmentObject(DataStore(clubsManager: ClubsDataManager()))
        .environmentObject(AuthService())
        .environmentObject(AppSettings())
}
