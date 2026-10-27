//
//  ImageLoader.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import UIKit

 final class ImageLoader: Sendable {

    static let shared = ImageLoader()

    private let cache: ImageCache
    private let session: URLSession

    init(cache: ImageCache = .shared, session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    func image(from url: URL, maxPixelSize: CGFloat) async throws -> UIImage {
        let key = "\(url.absoluteString)#\(Int(maxPixelSize))"
        if let cached = cache.image(for: key) {
            return cached
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              200...299 ~= http.statusCode else {
            throw APIError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let image = ImageDownsampler.downsample(data: data, maxPixelSize: maxPixelSize),
              let encoded = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.badStatus(-1)
        }
        cache.insert(image, data: encoded, for: key)
        return image
    }

    func image(from data: Data, key: String, maxPixelSize: CGFloat) async -> UIImage? {
        let cacheKey = "\(key)#\(Int(maxPixelSize))"
        if let cached = cache.image(for: cacheKey) {
            return cached
        }
        guard let image = ImageDownsampler.downsample(data: data, maxPixelSize: maxPixelSize),
              let encoded = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        cache.insert(image, data: encoded, for: cacheKey)
        return image
    }
}
