//
//  GlassDesign.swift
//  Campus
//
//  Liquid Glass design primitives for CampusPulse.
//  - SceneBackground: deep slate base + animated orange/violet blur blobs
//    so the .glassEffect material has rich content to refract.
//  - .glassCard()/.softCard(): material-backed card wrappers with hairline
//    strokes and graceful pre-iOS-26 fallbacks.
//  - .glassPrimaryButton()/.glassSecondaryButton(): branded button styles
//    that swap to the system glass button on iOS 26+.
//

import SwiftUI

// MARK: - Motion vocabulary

/// Shared animation curves used across the app so transitions feel
/// consistent and gently spring-driven.
enum AppMotion {
    static let smooth   = Animation.spring(response: 0.50, dampingFraction: 0.90)
    static let gentle   = Animation.spring(response: 0.42, dampingFraction: 0.88)
    static let snappy   = Animation.spring(response: 0.34, dampingFraction: 0.82)
    static let easeSoft = Animation.easeInOut(duration: 0.32)
}

// MARK: - Scene background

struct SceneBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            base
            blobs
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var base: some View {
        Group {
            if scheme == .dark {
                // Brighter, blueish slate instead of near-black so the
                // glass blur reads as airy rather than heavy.
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.16, blue: 0.23),
                        Color(red: 0.19, green: 0.22, blue: 0.30),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                // Very soft cream → off-white to give the orange blobs
                // room to glow without overwhelming the content.
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.98, blue: 0.96),
                        Color(red: 0.99, green: 0.96, blue: 0.93),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
    }

    private var blobs: some View {
        GeometryReader { geo in
            ZStack {
                blob(color: Theme.accent,
                     diameter: geo.size.width * 1.05,
                     position: CGPoint(x: -geo.size.width * 0.15,
                                       y: -geo.size.height * 0.05),
                     opacity: scheme == .dark ? 0.28 : 0.32)

                blob(color: secondaryBlob,
                     diameter: geo.size.width * 0.95,
                     position: CGPoint(x: geo.size.width * 1.1,
                                       y: geo.size.height * 0.55),
                     opacity: scheme == .dark ? 0.32 : 0.30)

                blob(color: tertiaryBlob,
                     diameter: geo.size.width * 0.7,
                     position: CGPoint(x: geo.size.width * 0.5,
                                       y: geo.size.height * 1.05),
                     opacity: scheme == .dark ? 0.28 : 0.22)
            }
        }
    }

    private var secondaryBlob: Color {
        scheme == .dark
            ? Color(red: 0.62, green: 0.42, blue: 0.92)   // softer lavender
            : Color(red: 1.00, green: 0.82, blue: 0.56)   // peach
    }

    private var tertiaryBlob: Color {
        scheme == .dark
            ? Color(red: 0.42, green: 0.66, blue: 0.94)   // soft sky
            : Color(red: 0.99, green: 0.90, blue: 0.78)   // light cream
    }

    private func blob(color: Color,
                      diameter: CGFloat,
                      position: CGPoint,
                      opacity: Double) -> some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .blur(radius: 120)
            .opacity(opacity)
            .position(position)
    }
}

// MARK: - Glass card modifier

extension View {
    /// Liquid-glass surface for primary content cards.
    @ViewBuilder
    func glassCard(tint: Color? = nil, radius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let glass: Glass = {
                if let tint { return .regular.tint(tint) }
                return .regular
            }()
            self
                .glassEffect(glass, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
                .overlay(
                    shape.stroke(
                        LinearGradient(colors: [Color.white.opacity(0.35),
                                                Color.clear],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
                )
        }
    }

    /// Subtler glass for secondary surfaces (inner rows, tiles).
    @ViewBuilder
    func softCard(radius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self.glassEffect(.clear, in: shape)
        } else {
            self
                .background(.thinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}

// MARK: - Button styles

struct GlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule(style: .continuous)
        let content = configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Theme.accent,
                                        Color(red: 0.88, green: 0.34, blue: 0.06)],
                               startPoint: .topLeading,
                               endPoint:   .bottomTrailing),
                in: shape
            )
            .overlay(shape.stroke(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(color: Theme.accent.opacity(0.35),
                    radius: configuration.isPressed ? 4 : 14,
                    x: 0, y: configuration.isPressed ? 1 : 7)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: configuration.isPressed)
        return content
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule(style: .continuous)
        return configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .glassCard(tint: Theme.accent.opacity(0.18), radius: 28)
            .overlay(shape.stroke(Theme.accent.opacity(0.35), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassPrimaryButtonStyle {
    static var glassPrimary: GlassPrimaryButtonStyle { .init() }
}

extension ButtonStyle where Self == GlassSecondaryButtonStyle {
    static var glassSecondary: GlassSecondaryButtonStyle { .init() }
}

// MARK: - Scene wrapper

/// Place this around a screen's content. It mounts the SceneBackground
/// behind the view and clears any default ScrollView/Form chrome so the
/// glass material can render against the live background.
struct GlassScene<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            SceneBackground()
            content()
        }
    }
}
