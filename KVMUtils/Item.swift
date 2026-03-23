//
//  Item.swift
//  KVMUtils
//
//  Created by Alvin Alford on 23/3/2026.
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
