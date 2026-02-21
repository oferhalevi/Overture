import AppKit
import CoreImage

/// Service for extracting dominant colors from album artwork
struct DominantColorExtractor {
    /// Extract dominant colors from an image
    func extractColors(from image: NSImage) -> ArtworkColors {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .default
        }

        // Resize image for faster processing
        guard let resizedImage = resizeImage(cgImage, to: Constants.ColorExtraction.sampleSize) else {
            return .default
        }

        // Get pixel data
        guard let pixelData = getPixelData(from: resizedImage) else {
            return .default
        }

        // Extract and sort colors by frequency
        let dominantColors = extractDominantColors(from: pixelData, width: Constants.ColorExtraction.sampleSize, height: Constants.ColorExtraction.sampleSize)

        guard dominantColors.count >= 3 else {
            return .default
        }

        return ArtworkColors(colors: dominantColors)
    }

    /// Resize image to target size
    private func resizeImage(_ cgImage: CGImage, to size: Int) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        return context?.makeImage()
    }

    /// Get raw pixel data from image
    private func getPixelData(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }

    /// Extract dominant colors using color bucketing
    private func extractDominantColors(from pixelData: [UInt8], width: Int, height: Int) -> [NSColor] {
        var colorBuckets: [String: (count: Int, r: Int, g: Int, b: Int)] = [:]
        let bucketSize = 32 // Reduce color space to 8 levels per channel

        let bytesPerPixel = 4
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = Int(pixelData[offset])
                let g = Int(pixelData[offset + 1])
                let b = Int(pixelData[offset + 2])
                let a = Int(pixelData[offset + 3])

                // Skip transparent pixels
                guard a > 128 else { continue }

                // Bucket the color
                let bucketR = (r / bucketSize) * bucketSize
                let bucketG = (g / bucketSize) * bucketSize
                let bucketB = (b / bucketSize) * bucketSize
                let key = "\(bucketR)-\(bucketG)-\(bucketB)"

                if var bucket = colorBuckets[key] {
                    bucket.count += 1
                    bucket.r += r
                    bucket.g += g
                    bucket.b += b
                    colorBuckets[key] = bucket
                } else {
                    colorBuckets[key] = (1, r, g, b)
                }
            }
        }

        // Sort by frequency and get top colors
        let sortedBuckets = colorBuckets.values.sorted { $0.count > $1.count }

        var selectedColors: [NSColor] = []
        let threshold = Constants.ColorExtraction.colorDifferenceThreshold

        for bucket in sortedBuckets {
            let r = CGFloat(bucket.r / bucket.count) / 255.0
            let g = CGFloat(bucket.g / bucket.count) / 255.0
            let b = CGFloat(bucket.b / bucket.count) / 255.0

            let color = NSColor(red: r, green: g, blue: b, alpha: 1.0)

            // Check if this color is sufficiently different from already selected colors
            let isDifferent = selectedColors.allSatisfy { existing in
                colorDistance(color, existing) > threshold
            }

            if isDifferent {
                selectedColors.append(color)

                if selectedColors.count >= Constants.ColorExtraction.colorCount {
                    break
                }
            }
        }

        // If we don't have enough colors, add variations
        while selectedColors.count < 3 {
            if let lastColor = selectedColors.last {
                selectedColors.append(darken(lastColor, by: 0.2))
            } else {
                selectedColors.append(NSColor.darkGray)
            }
        }

        return selectedColors
    }

    /// Calculate distance between two colors (0-1)
    private func colorDistance(_ c1: NSColor, _ c2: NSColor) -> CGFloat {
        guard let c1RGB = c1.usingColorSpace(.sRGB),
              let c2RGB = c2.usingColorSpace(.sRGB) else {
            return 0
        }

        let rDiff = c1RGB.redComponent - c2RGB.redComponent
        let gDiff = c1RGB.greenComponent - c2RGB.greenComponent
        let bDiff = c1RGB.blueComponent - c2RGB.blueComponent

        return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff) / sqrt(3.0)
    }

    /// Darken a color by a factor
    private func darken(_ color: NSColor, by factor: CGFloat) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            return color
        }

        return NSColor(
            red: max(0, rgb.redComponent - factor),
            green: max(0, rgb.greenComponent - factor),
            blue: max(0, rgb.blueComponent - factor),
            alpha: 1.0
        )
    }
}
