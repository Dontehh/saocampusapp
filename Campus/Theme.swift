//
//  Theme.swift
//  Campus
//
//  Design tokens for the CampusPulse SAO orange theme.
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum Theme {
    /// Vibrant SAO brand orange used for primary actions and accents.
    static let accent     = Color(red: 0.97, green: 0.45, blue: 0.09)
    static let accentSoft = Color(red: 1.00, green: 0.92, blue: 0.85)

    static var background       : Color { PlatformColor.systemBackground }
    static var surface          : Color { PlatformColor.secondarySystemBackground }
    static var surfaceElevated  : Color { PlatformColor.tertiarySystemBackground }

    static let slate      = Color(red: 0.18, green: 0.22, blue: 0.30)
    static let slateMuted = Color(red: 0.46, green: 0.52, blue: 0.61)
}

/// Cross-platform color shims so views can use the iOS-style names everywhere.
enum PlatformColor {
    static var systemBackground: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(.systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.white
        #endif
    }

    static var secondarySystemBackground: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(.secondarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color.gray.opacity(0.1)
        #endif
    }

    static var tertiarySystemBackground: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(.tertiarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.gray.opacity(0.15)
        #endif
    }
}
