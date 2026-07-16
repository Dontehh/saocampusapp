//
//  LoginView.swift
//  Campus
//
//  Editorial sign-in. Typography carries the design — a single accent
//  is reserved for the primary CTA and the informational pill. The
//  demo roster is available as tappable rows for quick access.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth:  AuthService
    @EnvironmentObject private var store: DataStore

    @State private var email = ""

    var body: some View {
        GlassScene {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Spacer(minLength: 32)
                    masthead
                    signInCard
                    demoRoster
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .contentFrame(max: AppLayout.readingMaxWidth)
            }
            .scrollContentBackground(.hidden)
        }
        .animation(AppMotion.smooth, value: auth.isAuthenticating)
        .animation(AppMotion.smooth, value: auth.loginError)
    }

    // MARK: - Sections

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Al Akhawayn University · SAO")
                .overlineStyle(Theme.accent)
            Text("CampusPulse")
                .font(AppFont.display)
                .foregroundStyle(Theme.ink)
            Text("Everything happening on campus — planned, run, and measured in one place.")
                .font(AppFont.body)
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sign in")
                    .font(AppFont.heading)
                    .foregroundStyle(Theme.ink)
                Text("Restricted to @aui.ma Microsoft accounts.")
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Email").overlineStyle()
                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                    TextField("you@aui.ma", text: $email)
                        .font(AppFont.body)
                        .foregroundStyle(Theme.ink)
                        .iosAutocap()
                        .emailKeyboard()
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit(signIn)
                        .disabled(auth.isAuthenticating)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Theme.fill,
                            in: RoundedRectangle(cornerRadius: AppLayout.controlRadius,
                                                 style: .continuous))
            }

            if let err = auth.loginError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(err)
                }
                .font(AppFont.captionStrong)
                .foregroundStyle(Theme.negative)
                .transition(.opacity)
            }

            Button(action: signIn) {
                HStack(spacing: 10) {
                    if auth.isAuthenticating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        MicrosoftMark()
                            .frame(width: 16, height: 16)
                    }
                    Text(auth.isAuthenticating ? "Signing in…" : "Continue with Microsoft")
                }
            }
            .buttonStyle(.glassPrimary)
            .disabled(auth.isAuthenticating || email.isEmpty)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11, weight: .medium))
                Text("Authenticated via aui.ma · MSAL")
                    .font(AppFont.caption)
            }
            .foregroundStyle(Theme.inkFaint)
        }
        .padding(22)
        .surfaceCard()
    }

    private var demoRoster: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Demo Accounts").overlineStyle()
            VStack(spacing: 0) {
                ForEach(Array(store.demoAccounts.enumerated()),
                        id: \.element.email) { index, account in
                    Button {
                        email = account.email
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.email)
                                    .font(AppFont.mono)
                                    .foregroundStyle(Theme.ink)
                                Text(account.role)
                                    .font(AppFont.caption)
                                    .foregroundStyle(Theme.inkMuted)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index != store.demoAccounts.count - 1 {
                        AppRule()
                    }
                }
            }
            .padding(.horizontal, 18)
            .surfaceCard()

            Text("Any other @aui.ma email signs in as a general student.")
                .font(AppFont.caption)
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private func signIn() {
        auth.signInWithMicrosoft(email: email, in: store)
    }
}

// MARK: - Microsoft mark

private struct MicrosoftMark: View {
    var body: some View {
        GeometryReader { geo in
            let gap = geo.size.width * 0.10
            let tile = (geo.size.width - gap) / 2
            ZStack(alignment: .topLeading) {
                tileRect(0, 0, tile, .init(red: 0.95, green: 0.32, blue: 0.21))
                tileRect(tile + gap, 0, tile, .init(red: 0.49, green: 0.74, blue: 0.27))
                tileRect(0, tile + gap, tile, .init(red: 0.00, green: 0.65, blue: 0.93))
                tileRect(tile + gap, tile + gap, tile, .init(red: 1.00, green: 0.72, blue: 0.00))
            }
        }
    }
    private func tileRect(_ x: CGFloat, _ y: CGFloat,
                          _ size: CGFloat, _ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
    }
}

#Preview {
    LoginView()
        .environmentObject(DataStore(clubsManager: ClubsDataManager()))
        .environmentObject(AuthService())
        .environmentObject(AppSettings())
}
