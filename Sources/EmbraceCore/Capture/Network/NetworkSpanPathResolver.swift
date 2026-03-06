//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

enum NetworkSpanPathResolver {
    static let headerName = "x-emb-path"
    private static let maxLength = 1024
    private static let validCharacters = try! NSRegularExpression(
        pattern: #"^[A-Za-z0-9\-._~:/\[\]@!$&'()*+,;=]+$"#
    )

    static func resolve(request: URLRequest, url: URL) -> String {
        if let candidate = request.value(forHTTPHeaderField: headerName), isValid(candidate) {
            return candidate
        }
        return url.path
    }

    static func isValid(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        guard path.count <= maxLength else { return false }
        guard path.canBeConverted(to: .ascii) else { return false }
        guard path.hasPrefix("/") else { return false }
        guard !path.contains("?"), !path.contains("#") else { return false }
        let range = NSRange(path.startIndex..., in: path)
        guard validCharacters.firstMatch(in: path, range: range) != nil else { return false }
        return true
    }
}
