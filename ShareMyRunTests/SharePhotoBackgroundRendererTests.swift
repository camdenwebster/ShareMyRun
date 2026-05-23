//
//  SharePhotoBackgroundRendererTests.swift
//  ShareMyRunTests
//
//  Created by Codex on 5/23/26.
//

import CoreGraphics
import Testing
import UIKit
@testable import ShareMyRun

@Suite("Share Photo Background Renderer Tests")
struct SharePhotoBackgroundRendererTests {

    @Test("Landscape photos are center cropped into square output")
    func landscapePhotosAreCenterCroppedIntoSquareOutput() {
        let photo = makePhoto(
            size: CGSize(width: 300, height: 100),
            bands: [
                (CGRect(x: 0, y: 0, width: 100, height: 100), UIColor.red),
                (CGRect(x: 100, y: 0, width: 100, height: 100), UIColor.green),
                (CGRect(x: 200, y: 0, width: 100, height: 100), UIColor.blue),
            ]
        )

        let rendered = SharePhotoBackgroundRenderer.render(photo, format: .square)

        #expect(rendered.size == ImageOutputFormat.square.size)
        #expect(rendered.isApproximatelyColor(.green, at: CGPoint(x: 0.02, y: 0.5)))
        #expect(rendered.isApproximatelyColor(.green, at: CGPoint(x: 0.5, y: 0.5)))
        #expect(rendered.isApproximatelyColor(.green, at: CGPoint(x: 0.98, y: 0.5)))
    }

    @Test("Portrait photos are center cropped into story output")
    func portraitPhotosAreCenterCroppedIntoStoryOutput() {
        let photo = makePhoto(
            size: CGSize(width: 100, height: 300),
            bands: [
                (CGRect(x: 0, y: 0, width: 100, height: 60), UIColor.red),
                (CGRect(x: 0, y: 60, width: 100, height: 180), UIColor.green),
                (CGRect(x: 0, y: 240, width: 100, height: 60), UIColor.blue),
            ]
        )

        let rendered = SharePhotoBackgroundRenderer.render(photo, format: .story)

        #expect(rendered.size == ImageOutputFormat.story.size)
        #expect(rendered.isApproximatelyColor(.green, at: CGPoint(x: 0.5, y: 0.02)))
        #expect(rendered.isApproximatelyColor(.green, at: CGPoint(x: 0.5, y: 0.5)))
        #expect(rendered.isApproximatelyColor(.green, at: CGPoint(x: 0.5, y: 0.98)))
    }

    private func makePhoto(
        size: CGSize,
        bands: [(rect: CGRect, color: UIColor)]
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            for band in bands {
                band.color.setFill()
                context.fill(band.rect)
            }
        }
    }
}

private extension UIImage {
    func isApproximatelyColor(
        _ expectedColor: UIColor,
        at normalizedPoint: CGPoint,
        tolerance: CGFloat = 0.04
    ) -> Bool {
        guard
            let expectedComponents = expectedColor.cgColor.converted(
                to: CGColorSpaceCreateDeviceRGB(),
                intent: .defaultIntent,
                options: nil
            )?.components,
            let actualComponents = colorComponents(at: normalizedPoint)
        else { return false }

        return zip(expectedComponents.prefix(3), actualComponents.prefix(3)).allSatisfy { expected, actual in
            abs(expected - actual) <= tolerance
        }
    }

    private func colorComponents(at normalizedPoint: CGPoint) -> [CGFloat]? {
        guard let cgImage else { return nil }

        let clampedX = min(max(normalizedPoint.x, 0), 1)
        let clampedY = min(max(normalizedPoint.y, 0), 1)
        let pixelX = Int(clampedX * CGFloat(cgImage.width - 1))
        let pixelY = Int(clampedY * CGFloat(cgImage.height - 1))
        var pixel = [UInt8](repeating: 0, count: 4)

        guard
            let context = CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        context.translateBy(x: -CGFloat(pixelX), y: -CGFloat(pixelY))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        return [
            CGFloat(pixel[0]) / 255,
            CGFloat(pixel[1]) / 255,
            CGFloat(pixel[2]) / 255,
            CGFloat(pixel[3]) / 255,
        ]
    }
}
