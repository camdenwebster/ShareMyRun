//
//  Item.swift
//  ShareMyRun
//
//  Created by Camden Webster on 1/18/26.
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
