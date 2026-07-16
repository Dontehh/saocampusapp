//
//  GlassDesign.swift
//  Campus
//
//  Surface primitives + motion tokens for the refined UI.
//  The design leans on paper-like cards with hairline strokes; glass is
//  reserved for the hero elements that genuinely benefit from depth.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Motion vocabulary

enum AppMotion {
    static let smooth   = Animation.spring(response: 0.42, dampingFraction: 0.90)
    static let gentle   = Animation.spring(response: 0.55, dampingFraction: 0.94)
    static let snappy   = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let easeSoft = Animation.easeInOut(duration: 0.28)
}

// MARK: - Scene background

/// Warm, single-tone canvas. No animated blobs — the design earns its
/// premium feel through restraint, not effects.
struct SceneBackground: View {
    var body: some View {
        Theme.background
            .ignoresSafeArea()
    }
}

// MARK: - Card modifiers

extension View {
    /// The default paper card. Solid surface, single hairline rule.
    @ViewBuilder
    func surfaceCard(radius: CGFloat = AppLayout.cardRadius) -> some View {
        self
            .background(Theme.surface,
                        in: RoundedRectangle(cornerRadius: radius,
                                             style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.rule, lineWidth: AppLayout.hairline)
            )
    }

    /// Subtle inset — used for rows within a surface card so hierarchy
    /// stays two-layer, no deeper.
    @ViewBuilder
    func insetSurface(radius: CGFloat = AppLayout.controlRadius) -> some View {
        self
            .background(Theme.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: radius,
                                             style: .continuous))
    }

    /// Hero card — reserved for the single most important element on a
    /// screen (dashboard hero, live-count tile). Uses an accent tint so
    /// the eye lands on it first.
    @ViewBuilder
    func heroCard(radius: CGFloat = 24) -> some View {
        self
            .background(Theme.accentSoft,
                        in: RoundedRectangle(cornerRadius: radius,
                                             style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.accent.opacity(0.28),
                            lineWidth: AppLayout.hairline)
            )
    }

    /// Backwards-compatible aliases for older call sites in the codebase.
    @ViewBuilder
    func glassCard(tint: Color? = nil, radius: CGFloat = 20) -> some View {
        if tint != nil {
            self.heroCard(radius: radius)
        } else {
            self.surfaceCard(radius: radius)
        }
    }

    @ViewBuilder
    func softCard(radius: CGFloat = AppLayout.controlRadius) -> some View {
        self.insetSurface(radius: radius)
    }
}

// MARK: - Button styles

struct GlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.bodyEmphasis)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.accent)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(AppMotion.snappy, value: configuration.isPressed)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.bodyEmphasis)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.rule, lineWidth: AppLayout.hairline)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(AppMotion.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassPrimaryButtonStyle {
    static var glassPrimary: GlassPrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == GlassSecondaryButtonStyle {
    static var glassSecondary: GlassSecondaryButtonStyle { .init() }
}

// MARK: - Scene wrapper

struct GlassScene<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            SceneBackground()
            content()
        }
    }
}

// MARK: - Tab bar tuning (kept for call-site compatibility)

extension View {
    @ViewBuilder
    func fluentTabBarBackground() -> some View {
        self
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbarBackground(.automatic, for: .navigationBar)
    }
}

// MARK: - Divider

/// Uniform hairline rule used inside cards.
struct AppRule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(height: AppLayout.hairline)
    }
}
