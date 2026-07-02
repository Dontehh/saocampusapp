//
//  Item.swift
//  Campus
//
//  Created by Ahmed Zahim on 22/6/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
