//
//  Theme.swift
//  Campus
//
//  Design tokens. Palette pulls warm cream / deep charcoal neutrals and
//  a single restrained sunset accent. Typography follows a strict scale
//  with distinct roles per row so hierarchy is carried by type, not
//  color. All tokens auto-resolve for light + dark scheme.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Appearance

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

// MARK: - Palette

enum Theme {

    // Accent — a single sunset used deliberately for CTAs and highlights.
    static let accent     = dynamic(light: (0.860, 0.383, 0.164),
                                    dark:  (0.945, 0.535, 0.286))
    static let accentSoft = dynamic(light: (0.985, 0.925, 0.883),
                                    dark:  (0.290, 0.180, 0.115))

    // Surfaces (paper, not glass — cards read as physical objects).
    static let background      = dynamic(light: (0.985, 0.968, 0.933),
                                         dark:  (0.086, 0.078, 0.070))
    static let surface         = dynamic(light: (1.000, 0.996, 0.980),
                                         dark:  (0.130, 0.121, 0.108))
    static let surfaceElevated = dynamic(light: (0.968, 0.949, 0.910),
                                         dark:  (0.164, 0.153, 0.137))

    // Text (labelled by role, not by hue).
    static let ink       = dynamic(light: (0.086, 0.070, 0.058),
                                   dark:  (0.960, 0.945, 0.910))
    static let inkMuted  = dynamic(light: (0.415, 0.375, 0.335),
                                   dark:  (0.655, 0.625, 0.575))
    static let inkFaint  = dynamic(light: (0.680, 0.640, 0.590),
                                   dark:  (0.415, 0.395, 0.360))

    // Structural — hairline rules and subtle field fills.
    static let rule      = dynamic(light: (0.898, 0.867, 0.815),
                                   dark:  (0.220, 0.200, 0.180))
    static let fill      = dynamic(light: (0.968, 0.949, 0.910),
                                   dark:  (0.164, 0.153, 0.137))

    // Semantic (kept restrained — used only where meaning demands hue).
    static let positive  = dynamic(light: (0.157, 0.470, 0.313),
                                   dark:  (0.400, 0.780, 0.510))
    static let warning   = dynamic(light: (0.760, 0.520, 0.113),
                                   dark:  (0.960, 0.720, 0.335))
    static let negative  = dynamic(light: (0.700, 0.180, 0.150),
                                   dark:  (0.960, 0.410, 0.360))

    // Legacy names retained so nothing calls a missing token during refactor.
    static var slate:      Color { ink }
    static var slateMuted: Color { inkMuted }
    static var accentSoft2: Color { accentSoft } // paranoia alias

    // MARK: - Dynamic color helper

    private static func dynamic(light: (Double, Double, Double),
                                dark:  (Double, Double, Double)) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            let (r, g, b) = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
        #else
        return Color(red: light.0, green: light.1, blue: light.2)
        #endif
    }
}

// MARK: - Typography

/// Strict typography scale. Views should compose from these — never
/// fall back to arbitrary sizes so hierarchy stays honest.
enum AppFont {
    static let display       = Font.system(size: 34, weight: .bold, design: .default)
    static let title         = Font.system(size: 24, weight: .semibold, design: .default)
    static let heading       = Font.system(size: 20, weight: .semibold, design: .default)
    static let headline      = Font.system(size: 17, weight: .semibold, design: .default)
    static let subheadline   = Font.system(size: 15, weight: .medium,   design: .default)
    static let body          = Font.system(size: 15, weight: .regular,  design: .default)
    static let bodyEmphasis  = Font.system(size: 15, weight: .semibold, design: .default)
    static let caption       = Font.system(size: 13, weight: .regular,  design: .default)
    static let captionStrong = Font.system(size: 13, weight: .semibold, design: .default)
    static let overline      = Font.system(size: 11, weight: .semibold, design: .default)
    static let mono          = Font.system(size: 12, weight: .regular,  design: .monospaced)

    static let displayNumber = Font.system(size: 42, weight: .semibold, design: .rounded)
    static let heroNumber    = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let statNumber    = Font.system(size: 22, weight: .semibold, design: .rounded)
}

// MARK: - Text style modifier

extension Text {
    /// Small-caps section labels ("UPCOMING", "STRENGTHS"), tracked wide.
    func overlineStyle(_ color: Color = Theme.inkMuted) -> some View {
        self
            .font(AppFont.overline)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Layout constants

enum AppLayout {
    /// Cap content width on wide screens so lines stay readable and the
    /// visual weight of the design carries at any size.
    static let contentMaxWidth: CGFloat = 720
    static let readingMaxWidth: CGFloat = 640

    static let gutter: CGFloat        = 20
    static let sectionGap: CGFloat    = 28
    static let cardRadius: CGFloat    = 20
    static let controlRadius: CGFloat = 14
    static let hairline: CGFloat      = 0.5
}

extension View {
    /// Center + cap max width so an iPad or landscape iPhone doesn't
    /// stretch content edge to edge. The outer `.frame(maxWidth: .infinity)`
    /// keeps the cell greedy for centering.
    func contentFrame(max: CGFloat = AppLayout.contentMaxWidth) -> some View {
        self
            .frame(maxWidth: max)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
