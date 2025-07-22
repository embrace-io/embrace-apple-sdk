//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import Foundation

class Request: ObservableObject {
    @Published var requestResult: String = ""

    func executeRequest(urlString: String, httpMethod: String, requestBody: String?) {
        guard let url = URL(string: urlString) else {
            Embrace.client?.log("URL is not valid: \(urlString)", severity: .error)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod

        if let requestBody = requestBody, !requestBody.isEmpty {
            request.httpBody = requestBody.data(using: .utf8)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }

                if let error = error {
                    self.requestResult = "Error: \(error.localizedDescription)"
                    return
                }

                guard let response = response as? HTTPURLResponse, let data = data else {
                    self.requestResult = "No response"
                    return
                }

                var result = "Request Method: \(httpMethod)\n"
                result += "Request URL: \(urlString)\n"
                result += "Request Headers: \(request.allHTTPHeaderFields ?? [:])\n"
                result += "Request Body: \(requestBody ?? "None")\n"

                result += "\n--- Response ---\n"
                result += "Status Code: \(response.statusCode)\n"
                result += "Response Headers: \(response.allHeaderFields)\n"
                let responseString = String(decoding: data, as: UTF8.self)
                result += "Response Body: \(responseString)"

                self.requestResult = result
            }
        }
        task.resume()
    }
}
