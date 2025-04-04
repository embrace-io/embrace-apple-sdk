//
//  NetworkingTestClient.swift
//  EmbraceIOTestApp
//
//

import Foundation

@Observable class NetworkingTestClient {
    enum Status {
        case idle
        case fetching
        case success(code: Int)
        case failed(error: Error)
    }

    enum NetworkError: Error {
        case invalidURL
        case invalidBody
        case invalidResponse
    }

    private(set) var status = Status.idle

    func makeTestNetworkCall(to urlString: String) async {
        self.status = .fetching
        do {
            guard let url = URL(string: urlString) else {
                throw NetworkError.invalidURL
            }

            let (_, res) = try await URLSession.shared.data(from: url)

            guard let res = res as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            self.status = .success(code: res.statusCode)
        } catch {
            self.status = .failed(error: error)
        }
    }

    func makeTestUploadRequest(to urlString: String, method: URLRequestMethod = .post, body: [String: String]) async {
        self.status = .fetching
        do {
            guard let url = URL(string: urlString) else {
                throw NetworkError.invalidURL
            }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpMethod = method.description
            let encoder = JSONEncoder()

            guard let data = try? encoder.encode(body) else {
                throw NetworkError.invalidBody
            }

            request.httpBody = data

            let (_, res) = try await URLSession.shared.data(for: request)

            guard let res = res as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            self.status = .success(code: res.statusCode)
        } catch {
            self.status = .failed(error: error)
        }
    }

    func clear() {
        self.status = .idle
    }
}
