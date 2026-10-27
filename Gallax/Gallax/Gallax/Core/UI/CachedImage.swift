//
//  CachedImage.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import SwiftUI

struct CachedImage: View {

    let localData: Data?
    let remoteURL: String?
    let cacheKey: String
    var maxPixelSize: CGFloat = ImageDownsampler.thumbnailMaxPixel

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                }
            } else {
                ZStack {
                    Color.gray.opacity(0.12)
                    Image(systemName: didFail ? "wifi.slash" : "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: taskIdentity) {
            await load()
        }
    }

    private var taskIdentity: String {
        "\(cacheKey)#\(Int(maxPixelSize))#\(remoteURL ?? "")#\(localData?.count ?? 0)"
    }

    private func load() async {
        guard image == nil else { return }
        isLoading = true
        didFail = false
        defer { isLoading = false }

        if let localData {
            let decoded = await ImageLoader.shared.image(from: localData,
                                                         key: cacheKey,
                                                         maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            if let decoded {
                image = decoded
                return
            }
        }

        guard let remoteURL, let url = URL(string: remoteURL) else {
            didFail = localData != nil
            return
        }

        do {
            let loaded = try await ImageLoader.shared.image(from: url, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            image = loaded
        } catch {
            guard !Task.isCancelled else { return }
            didFail = true
        }
    }
}
