//
//  StatisticsOverlayRenderer.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import UIKit
import SwiftUI

/// Renders statistics text overlay on images
final class StatisticsOverlayRenderer {

    /// Configuration for statistics rendering
    struct Configuration {
        /// Size of the output image
        let size: CGSize

        /// Statistics to display
        let statistics: [(StatisticType, String)]

        /// A highlighted statistic rendered larger opposite the main stack
        let featuredStatistic: (StatisticType, String)?

        /// Font name
        let fontName: String

        /// Font size
        let fontSize: CGFloat

        /// Text color
        let textColor: UIColor

        /// Position of the text
        let position: TextPosition

        /// Whether to add shadow for readability
        let addShadow: Bool

        /// Padding from edges
        let padding: CGFloat

        init(
            size: CGSize,
            statistics: [(StatisticType, String)],
            featuredStatistic: (StatisticType, String)? = nil,
            fontName: String = ".AppleSystemUIFont",
            fontSize: CGFloat = 24,
            textColor: UIColor = .white,
            position: TextPosition = .bottomLeft,
            addShadow: Bool = true,
            padding: CGFloat = 32
        ) {
            self.size = size
            self.statistics = statistics
            self.featuredStatistic = featuredStatistic
            self.fontName = fontName
            self.fontSize = fontSize
            self.textColor = textColor
            self.position = position
            self.addShadow = addShadow
            self.padding = padding
        }
    }

    // MARK: - Rendering

    /// Renders statistics overlay onto a base image
    /// - Parameters:
    ///   - baseImage: The background image to render onto
    ///   - configuration: Rendering configuration
    /// - Returns: Image with statistics overlay
    func render(
        onto baseImage: UIImage,
        configuration: Configuration
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: configuration.size)

        return renderer.image { context in
            // Draw base image scaled to fill
            drawBaseImage(baseImage, in: context, size: configuration.size)

            // Add semi-transparent gradient for text readability if needed
            let blockHeight = textBlockHeight(configuration: configuration)
            if configuration.addShadow {
                drawReadabilityGradient(
                    context: context,
                    position: configuration.position,
                    size: configuration.size,
                    contentHeight: blockHeight
                )
            }

            // Draw statistics
            drawStatistics(context: context, configuration: configuration)
        }
    }

    /// Renders statistics overlay as transparent image (for compositing)
    /// - Parameter configuration: Rendering configuration
    /// - Returns: Transparent image with only the statistics text
    func renderOverlay(configuration: Configuration) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: configuration.size)

        return renderer.image { context in
            drawStatistics(context: context, configuration: configuration)
        }
    }

    // MARK: - Private Helpers

    /// Draws the base image scaled to fill
    private func drawBaseImage(_ image: UIImage, in context: UIGraphicsImageRendererContext, size: CGSize) {
        let aspectFill = calculateAspectFillRect(for: image.size, in: size)
        image.draw(in: aspectFill)
    }

    /// Calculates the rect for aspect fill drawing
    private func calculateAspectFillRect(for imageSize: CGSize, in targetSize: CGSize) -> CGRect {
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let ratio = max(widthRatio, heightRatio)

        let newSize = CGSize(
            width: imageSize.width * ratio,
            height: imageSize.height * ratio
        )

        let origin = CGPoint(
            x: (targetSize.width - newSize.width) / 2,
            y: (targetSize.height - newSize.height) / 2
        )

        return CGRect(origin: origin, size: newSize)
    }

    /// Draws a gradient to improve text readability
    private func drawReadabilityGradient(
        context: UIGraphicsImageRendererContext,
        position: TextPosition,
        size: CGSize,
        contentHeight: CGFloat
    ) {
        let minimumHeight: CGFloat = size.height * 0.40
        let preferredHeight = contentHeight + (size.height * 0.12)
        let gradientHeight: CGFloat = min(size.height * 0.75, max(minimumHeight, preferredHeight))

        let colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.5).cgColor
        ]

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0, 1]
        ) else { return }

        let rect: CGRect
        let startPoint: CGPoint
        let endPoint: CGPoint

        switch position {
        case .topLeft, .topRight:
            rect = CGRect(x: 0, y: 0, width: size.width, height: gradientHeight)
            startPoint = CGPoint(x: size.width / 2, y: gradientHeight)
            endPoint = CGPoint(x: size.width / 2, y: 0)
        case .bottomLeft, .bottomRight:
            rect = CGRect(x: 0, y: size.height - gradientHeight, width: size.width, height: gradientHeight)
            startPoint = CGPoint(x: size.width / 2, y: size.height - gradientHeight)
            endPoint = CGPoint(x: size.width / 2, y: size.height)
        case .center:
            // No gradient for center position
            return
        }

        context.cgContext.saveGState()
        context.cgContext.addRect(rect)
        context.cgContext.clip()
        context.cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        context.cgContext.restoreGState()
    }

    /// Draws the statistics text
    private func drawStatistics(context: UIGraphicsImageRendererContext, configuration: Configuration) {
        let valueFont = resolvedFont(named: configuration.fontName, size: configuration.fontSize)
        let featuredValueFont = resolvedFont(named: configuration.fontName, size: configuration.fontSize * 1.85)
        let featuredLabelFont = resolvedFont(named: configuration.fontName, size: configuration.fontSize * 0.60)
        let iconConfig = UIImage.SymbolConfiguration(pointSize: configuration.fontSize, weight: .semibold)

        var attributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: configuration.textColor
        ]

        // Add shadow if enabled
        if configuration.addShadow {
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.7)
            shadow.shadowOffset = CGSize(width: 1, height: 1)
            shadow.shadowBlurRadius = 3
            attributes[.shadow] = shadow
        }

        // Calculate text block
        var lines: [(stat: StatisticType, text: NSAttributedString, textSize: CGSize)] = []
        var maxWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        let lineSpacing: CGFloat = 8
        let iconSpacing: CGFloat = 10

        for (stat, value) in configuration.statistics {
            let attributedText = NSAttributedString(string: value, attributes: attributes)
            let textSize = attributedText.size()

            let iconWidth = UIImage(systemName: stat.iconName, withConfiguration: iconConfig)?.size.width ?? 0
            let lineWidth = iconWidth > 0 ? iconWidth + iconSpacing + textSize.width : textSize.width
            let lineHeight = max(textSize.height, configuration.fontSize)

            lines.append((stat: stat, text: attributedText, textSize: textSize))
            maxWidth = max(maxWidth, lineWidth)
            totalHeight += lineHeight + lineSpacing
        }

        // Remove extra spacing from last line
        if !lines.isEmpty {
            totalHeight -= lineSpacing
        }

        // Calculate starting position based on text position
        let origin = calculateTextOrigin(
            textSize: CGSize(width: maxWidth, height: totalHeight),
            position: configuration.position,
            imageSize: configuration.size,
            padding: configuration.padding
        )

        // Draw each line
        var currentY = origin.y
        for line in lines {
            let textSize = line.textSize
            let icon = UIImage(systemName: line.stat.iconName, withConfiguration: iconConfig)
            let iconSize = icon?.size ?? .zero
            let contentWidth = iconSize.width > 0 ? iconSize.width + iconSpacing + textSize.width : textSize.width
            let x: CGFloat

            switch configuration.position {
            case .topLeft, .bottomLeft:
                x = origin.x
            case .topRight, .bottomRight:
                x = origin.x + maxWidth - contentWidth
            case .center:
                x = origin.x + (maxWidth - contentWidth) / 2
            }

            var textX = x

            if let icon {
                let iconY = currentY + max(0, (textSize.height - iconSize.height) / 2)
                icon.withTintColor(configuration.textColor, renderingMode: .alwaysOriginal)
                    .draw(at: CGPoint(x: x, y: iconY))
                textX += iconSize.width + iconSpacing
            }

            line.text.draw(at: CGPoint(x: textX, y: currentY))
            currentY += max(textSize.height, configuration.fontSize) + lineSpacing
        }

        drawFeaturedStatistic(
            configuration: configuration,
            valueFont: featuredValueFont,
            labelFont: featuredLabelFont,
            shadow: attributes[.shadow] as? NSShadow
        )
    }

    private func drawFeaturedStatistic(
        configuration: Configuration,
        valueFont: UIFont,
        labelFont: UIFont,
        shadow: NSShadow?
    ) {
        guard let featured = configuration.featuredStatistic else { return }

        var valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: configuration.textColor
        ]
        var labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: configuration.textColor.withAlphaComponent(0.95)
        ]

        if let shadow {
            valueAttributes[.shadow] = shadow
            labelAttributes[.shadow] = shadow
        }

        let valueText = NSAttributedString(string: featured.1, attributes: valueAttributes)
        let labelText = NSAttributedString(string: featured.0.displayName.uppercased(), attributes: labelAttributes)

        let valueSize = valueText.size()
        let labelSize = labelText.size()
        let totalHeight = valueSize.height + labelSize.height + 6
        let blockWidth = max(valueSize.width, labelSize.width)

        let origin = calculateFeaturedOrigin(
            blockSize: CGSize(width: blockWidth, height: totalHeight),
            position: configuration.position,
            imageSize: configuration.size,
            padding: configuration.padding
        )

        valueText.draw(at: origin)
        let labelX = origin.x + ((blockWidth - labelSize.width) / 2)
        labelText.draw(at: CGPoint(x: labelX, y: origin.y + valueSize.height + 6))
    }

    private func calculateFeaturedOrigin(
        blockSize: CGSize,
        position: TextPosition,
        imageSize: CGSize,
        padding: CGFloat
    ) -> CGPoint {
        let y: CGFloat
        switch position {
        case .topLeft, .topRight:
            y = padding
        case .bottomLeft, .bottomRight:
            y = imageSize.height - blockSize.height - padding
        case .center:
            y = (imageSize.height - blockSize.height) / 2
        }

        let x: CGFloat
        switch position {
        case .topLeft, .bottomLeft:
            x = imageSize.width - blockSize.width - padding
        case .topRight, .bottomRight:
            x = padding
        case .center:
            x = imageSize.width - blockSize.width - padding
        }

        return CGPoint(x: x, y: y)
    }

    private func textBlockHeight(configuration: Configuration) -> CGFloat {
        let lineSpacing: CGFloat = 8
        let statsLineHeight = configuration.statistics.isEmpty
            ? 0
            : CGFloat(configuration.statistics.count) * configuration.fontSize + CGFloat(max(configuration.statistics.count - 1, 0)) * lineSpacing

        let featuredHeight: CGFloat
        if configuration.featuredStatistic == nil {
            featuredHeight = 0
        } else {
            featuredHeight = (configuration.fontSize * 1.85) + (configuration.fontSize * 0.60) + 6
        }

        return max(statsLineHeight, featuredHeight) + (configuration.padding * 0.5)
    }

    private func resolvedFont(named fontName: String, size: CGFloat) -> UIFont {
        if fontName == ".AppleSystemUIFontRounded" {
            let baseDescriptor = UIFont.systemFont(ofSize: size, weight: .semibold).fontDescriptor
            if let roundedDescriptor = baseDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: roundedDescriptor, size: size)
            }
            return UIFont.systemFont(ofSize: size, weight: .semibold)
        }

        if fontName == ".AppleSystemUIFont" {
            return UIFont.systemFont(ofSize: size, weight: .semibold)
        }

        return UIFont(name: fontName, size: size) ??
            UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    /// Calculates the origin point for text based on position
    private func calculateTextOrigin(
        textSize: CGSize,
        position: TextPosition,
        imageSize: CGSize,
        padding: CGFloat
    ) -> CGPoint {
        switch position {
        case .topLeft:
            return CGPoint(x: padding, y: padding)
        case .topRight:
            return CGPoint(x: imageSize.width - textSize.width - padding, y: padding)
        case .bottomLeft:
            return CGPoint(x: padding, y: imageSize.height - textSize.height - padding)
        case .bottomRight:
            return CGPoint(x: imageSize.width - textSize.width - padding, y: imageSize.height - textSize.height - padding)
        case .center:
            return CGPoint(
                x: (imageSize.width - textSize.width) / 2,
                y: (imageSize.height - textSize.height) / 2
            )
        }
    }
}
