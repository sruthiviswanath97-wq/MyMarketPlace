//
//  ImageCache.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import CryptoKit
import UIKit

 final class ImageCache: Sendable {

    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskDirectory: URL
    private let fileManager = FileManager.default

    init(countLimit: Int = 150,
         memoryLimitBytes: Int = 40 * 1024 * 1024) {
        memoryCache.countLimit = countLimit
        memoryCache.totalCostLimit = memoryLimitBytes

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDirectory = caches.appendingPathComponent("GallaxImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Read

    func image(for key: String) -> UIImage? {
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        let fileURL = diskURL(for: key)
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        storeInMemory(image, for: key)
        return image
    }


    func insert(_ image: UIImage, data: Data, for key: String) {
        storeInMemory(image, for: key)
        let fileURL = diskURL(for: key)
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func removeAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskDirectory)
        try? fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }


    private func storeInMemory(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    private func diskURL(for key: String) -> URL {
        let hashed = SHA256.hash(data: Data(key.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
        return diskDirectory.appendingPathComponent(hashed).appendingPathExtension("jpg")
    }
}
