//
//  ImageDownsamplerTests.swift
//  GallaxTests
//
//  Created by sruthi.e01 on 25/10/26.
//

import UIKit
import XCTest
@testable import Gallax

final class ImageDownsamplerTests: XCTestCase {

    /// Builds a solid-colour JPEG of the requested pixel size.
    private func makeImageData(width: CGFloat, height: CGFloat) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height),
                                               format: format)
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
    }

    func testDownsampleReducesPixelDimensions() throws {
        let data = try makeImageData(width: 2000, height: 1000)
        let result = try XCTUnwrap(
            ImageDownsampler.downsample(data: data, maxPixelSize: 200, scale: 1)
        )
        XCTAssertEqual(max(result.size.width, result.size.height), 200, accuracy: 1)
        XCTAssertEqual(result.size.height, 100, accuracy: 1)
    }

    func testDownsamplePreservesAspectRatio() throws {
        let data = try makeImageData(width: 1600, height: 400)
        let result = try XCTUnwrap(
            ImageDownsampler.downsample(data: data, maxPixelSize: 400, scale: 1)
        )
        XCTAssertEqual(result.size.width / result.size.height, 4, accuracy: 0.05)
    }

    func testThumbnailDataIsSmallerThanOriginal() throws {
        let data = try makeImageData(width: 2400, height: 2400)
        let thumbnail = try XCTUnwrap(ImageDownsampler.thumbnailData(from: data))
        XCTAssertLessThan(thumbnail.count, data.count)
    }

    func testDownsampleRejectsNonImageData() {
        let garbage = Data("not an image".utf8)
        XCTAssertNil(ImageDownsampler.downsample(data: garbage, maxPixelSize: 100, scale: 1))
    }
}
