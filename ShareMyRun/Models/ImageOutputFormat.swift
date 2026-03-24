//
//  ImageOutputFormat.swift
//  ShareMyRun
//
//  Created by Codex on 2/22/26.
//

import Foundation
import CoreGraphics

/// Output format options for generated share images.
enum ImageOutputFormat: String, CaseIterable, Identifiable, Codable {
    case square = "Square"
    case story = "Story"

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .square:
            return CGSize(width: 1080, height: 1080)
        case .story:
            return CGSize(width: 1080, height: 1920)
        }
    }

    var aspectRatio: CGFloat {
        size.width / size.height
    }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .square:
            return "square"
        case .story:
            return "rectangle.portrait"
        }
    }
}
