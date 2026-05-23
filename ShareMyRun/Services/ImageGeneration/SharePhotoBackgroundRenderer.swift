//
//  SharePhotoBackgroundRenderer.swift
//  ShareMyRun
//
//  Created by Codex on 5/23/26.
//

import CoreGraphics
import UIKit

/// Renders photo backgrounds into the selected share-image canvas.
enum SharePhotoBackgroundRenderer {
    static func render(_ photo: UIImage, format: ImageOutputFormat) -> UIImage {
        render(photo, size: format.size)
    }

    static func render(_ photo: UIImage, size targetSize: CGSize) -> UIImage {
        guard targetSize.width > 0, targetSize.height > 0 else {
            return photo
        }

        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            photo.draw(in: aspectFillRect(for: photo.size, in: targetSize))
        }
    }

    static func aspectFillRect(for imageSize: CGSize, in targetSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: targetSize)
        }

        let ratio = max(
            targetSize.width / imageSize.width,
            targetSize.height / imageSize.height
        )
        let scaledSize = CGSize(
            width: imageSize.width * ratio,
            height: imageSize.height * ratio
        )

        return CGRect(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
}
