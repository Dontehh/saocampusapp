//
//  AppSettings.swift
//  Campus
//
//  Shared, observable settings. Hoisting appearance into an
//  ObservableObject guarantees the picker in AccountMenu and the
//  preferredColorScheme on the root scene always observe the same value.
//

import Foundation
import SwiftUI
import Combine

final class AppSettings: ObservableObject {

    private static let appearanceKey = "appearance"

    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue,
                                      forKey: Self.appearanceKey)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.appearanceKey) ?? ""
        self.appearance = AppAppearance(rawValue: raw) ?? .system
    }
}
