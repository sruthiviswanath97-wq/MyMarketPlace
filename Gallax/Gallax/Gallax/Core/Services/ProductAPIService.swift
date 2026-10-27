//
//  ProductAPIService.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//
//  Network layer backed by the public https://dummyjson.com mock API.
//

import Foundation

enum APIError: LocalizedError {
    case badURL
    case badStatus(Int)
    case offline

    var errorDescription: String? {
        switch self {
        case .badURL: return "The request URL was invalid."
        case .badStatus(let code): return "Server responded with status \(code)."
        case .offline: return "No network connection."
        }
    }
}

final class ProductAPIService: GalleryServicing {

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "https://dummyjson.com")!,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        return decoder
    }()

    func fetchItems(limit: Int) async throws -> [RemoteItem] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("products"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components?.url else { throw APIError.badURL }

        let data = try await perform(URLRequest(url: url))
        let list = try Self.decoder.decode(ProductListResponse.self, from: data)
        return list.products.map(RemoteItem.init(dto:))
    }

    func createItem(title: String, description: String) async throws -> RemoteItem {
        let url = baseURL.appendingPathComponent("products/add")
        let request = try jsonRequest(url: url,
                                      method: "POST",
                                      body: ProductRequest(title: title, description: description))
        let data = try await perform(request)
        return RemoteItem(dto: try Self.decoder.decode(ProductDTO.self, from: data))
    }

    func updateItem(remoteId: String, title: String, description: String) async throws -> RemoteItem {
        let url = baseURL.appendingPathComponent("products/\(remoteId)")
        let request = try jsonRequest(url: url,
                                      method: "PUT",
                                      body: ProductRequest(title: title, description: description))
        let data = try await perform(request)
        return RemoteItem(dto: try Self.decoder.decode(ProductDTO.self, from: data))
    }

    func deleteItem(remoteId: String) async throws {
        let url = baseURL.appendingPathComponent("products/\(remoteId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await perform(request)
    }

    private func jsonRequest<Body: Encodable>(url: URL,
                                              method: String,
                                              body: Body) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.badStatus(-1)
            }
            guard 200...299 ~= http.statusCode else {
                throw APIError.badStatus(http.statusCode)
            }
            return data
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw APIError.offline
        }
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .dataNotAllowed,
        .cannotConnectToHost,
        .timedOut
    ]
}

private extension JSONDecoder.DateDecodingStrategy {
    /// dummyjson returns timestamps like `2025-04-30T09:41:02.053Z`.
    static let iso8601WithFractionalSeconds = custom { decoder in
        let text = try decoder.singleValueContainer().decode(String.self)
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return date }

        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath,
                  debugDescription: "Unrecognised date: \(text)")
        )
    }
}
