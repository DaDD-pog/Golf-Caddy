//
//  Item.swift
//  Golf Caddy Companion
//
//  Created by Donald Weldon on 3/17/26.
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
