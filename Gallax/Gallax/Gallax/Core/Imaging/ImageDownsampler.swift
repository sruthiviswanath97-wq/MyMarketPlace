//
//  ImageDownsampler.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import ImageIO
import UIKit

 enum ImageDownsampler {

    static let thumbnailMaxPixel: CGFloat = 300

    static let detailMaxPixel: CGFloat = 1200
    static let defaultScale: CGFloat = 3

    static func downsample(data: Data,
                           maxPixelSize: CGFloat,
                           scale: CGFloat = defaultScale) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        return downsample(source: source, maxPixelSize: maxPixelSize, scale: scale)
    }

    private static func downsample(source: CGImageSource,
                                   maxPixelSize: CGFloat,
                                   scale: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize * scale
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
    static func thumbnailData(from data: Data,
                              maxPixelSize: CGFloat = thumbnailMaxPixel,
                              compression: CGFloat = 0.7) -> Data? {
        downsample(data: data, maxPixelSize: maxPixelSize)?
            .jpegData(compressionQuality: compression)
    }
}
