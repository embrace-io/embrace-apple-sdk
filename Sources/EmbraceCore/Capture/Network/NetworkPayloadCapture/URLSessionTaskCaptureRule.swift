//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceConfiguration

class URLSessionTaskCaptureRule {

    private var rule: NetworkPayloadCaptureRule
    private let regex: NSRegularExpression?
    let publicKey: String

    var id: String {
        return rule.id
    }
    var urlRegex: String {
        return rule.urlRegex
    }
    var expirationDate: Date {
        return rule.expirationDate
    }

    init(rule: NetworkPayloadCaptureRule) {
        self.rule = rule

        do {
            regex = try NSRegularExpression(pattern: rule.urlRegex, options: .caseInsensitive)
        } catch {
            Embrace.logger.error("Error trying to create regex \"\(rule.urlRegex)\" for rule \(rule.id)!\n\(error.localizedDescription)")
            regex = nil
        }

        self.publicKey = URLSessionTaskCaptureRule.sanitize(rule.publicKey)
    }

    func shouldTriggerFor(request: URLRequest?, response: URLResponse?, error: Error?) -> Bool {

        guard let request = request,
              let url = request.url,
              let method = request.httpMethod,
              expirationDate > Date() else {
            return false
        }

        // ignore requests to Embrace's back end
        if let endpoints = Embrace.client?.options.endpoints {
            guard !url.absoluteString.contains(endpoints.baseURL) else {
                return false
            }
        }

        // check that the url matches
        guard urlMatches(url.absoluteString) else {
            return false
        }

        // check that the method matches
        if let methods = rule.methods {
            guard methods.contains(method) else {
                return false
            }
        }

        // check status codes
        if let statusCodes = rule.statusCodes {

            // if -1 is passed as a status code for the rule
            // it means we should capture any requests that errors
            if statusCodes.contains(-1) && error != nil {
                return true
            }

            // check if the status code matches
            if let statusCode = (response as? HTTPURLResponse)?.statusCode,
               statusCodes.contains(statusCode) {
                return true
            }

            return false
        }

        return true
    }

    private func urlMatches(_ url: String) -> Bool {
        guard let regex = regex else {
            return false
        }

        let matches = regex.matches(in: url, range: NSRange(location: 0, length: url.count))
        return matches.count > 0
    }

    static private func sanitize(_ key: String) -> String {
        return key
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
