//
//  PlatformShims.swift
//  Campus
//
//  Thin wrappers around iOS-only SwiftUI APIs so the project can still
//  compile on other platforms in the project's destination list.
//  CampusPulse is designed as an iPhone/iPad app — the macOS build is
//  best-effort only.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Navigation title

extension View {
    @ViewBuilder
    func largeNavTitle() -> some View {
        #if os(iOS) || os(visionOS) || os(tvOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }

    @ViewBuilder
    func inlineNavTitle() -> some View {
        #if os(iOS) || os(visionOS) || os(tvOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - Search

extension View {
    @ViewBuilder
    func searchableBar(text: Binding<String>, prompt: String) -> some View {
        #if os(iOS) || os(visionOS)
        self.searchable(text: text,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: prompt)
        #else
        self.searchable(text: text, prompt: prompt)
        #endif
    }
}

// MARK: - Toolbar placement aliases

extension ToolbarItemPlacement {
    static var trailingBar: ToolbarItemPlacement {
        #if os(iOS) || os(visionOS) || os(tvOS)
        return .topBarTrailing
        #elseif os(macOS)
        return .primaryAction
        #else
        return .automatic
        #endif
    }

    static var leadingBar: ToolbarItemPlacement {
        #if os(iOS) || os(visionOS) || os(tvOS)
        return .topBarLeading
        #elseif os(macOS)
        return .cancellationAction
        #else
        return .automatic
        #endif
    }
}

// MARK: - Text field helpers

extension View {
    @ViewBuilder
    func iosAutocap(_ disabled: Bool = true) -> some View {
        #if os(iOS) || os(visionOS) || os(tvOS)
        self.textInputAutocapitalization(disabled ? .never : .sentences)
        #else
        self
        #endif
    }

    @ViewBuilder
    func emailKeyboard() -> some View {
        #if os(iOS) || os(visionOS) || os(tvOS)
        self.keyboardType(.emailAddress)
        #else
        self
        #endif
    }
}

// MARK: - List styling

extension View {
    @ViewBuilder
    func plainListStyle() -> some View {
        #if os(macOS)
        self.listStyle(.inset)
        #else
        self.listStyle(.plain)
        #endif
    }
}

// MARK: - Image abstraction for the QR code

#if canImport(UIKit)
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}
