//
//  ProductDTO.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//
//  Wire format for https://dummyjson.com/products
//

import Foundation

struct ProductListResponse: Decodable {
    let products: [ProductDTO]
    let total: Int
    let skip: Int
    let limit: Int
}

struct ProductDTO: Decodable {
    let id: Int
    let title: String
    let description: String?
    let thumbnail: String?
    let images: [String]?
    let meta: ProductMeta?

    var previewImageURL: String? {
        thumbnail ?? images?.first
    }
}

struct ProductMeta: Decodable {
    let createdAt: Date?
    let updatedAt: Date?
}

struct ProductRequest: Encodable {
    let title: String
    let description: String
}

struct RemoteItem: Equatable {
    let remoteId: String
    let title: String
    let description: String
    let imageURL: String?
    let updatedAt: Date?
}

extension RemoteItem {
    init(dto: ProductDTO) {
        self.init(remoteId: String(dto.id),
                  title: dto.title,
                  description: dto.description ?? "",
                  imageURL: dto.previewImageURL,
                  updatedAt: dto.meta?.updatedAt)
    }
}
