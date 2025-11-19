//
//  FetchController.swift
//  tvosTestApp
//
//

import Foundation

struct FetchController {
    enum NetworkError: Error {
        case invalidURL
        case invalidResponse
        case badData
    }
    
    func fetch(_ baseURL: URL, endpoint: String) async throws -> Data {
        let api = baseURL.appendingPathComponent(endpoint)
        let fetchURLComponents = URLComponents(url: api, resolvingAgainstBaseURL: true)
        
        guard let fetchURL = fetchURLComponents?.url else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: fetchURL)
        
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200
        else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
}

extension FetchController {
    func fetchWWDCData() async throws -> WWDCData? {
        let baseURL = URL(string: "https://nonstrict.eu")!
        let rawDictionary = try await fetch(baseURL, endpoint: "wwdcindex/data.json")
        
        guard let wwdcData = try? JSONDecoder().decode(WWDCData.self, from: rawDictionary) else {
            throw NetworkError.badData
        }

        return wwdcData
    }
}
