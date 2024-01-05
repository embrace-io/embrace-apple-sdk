//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLRequest {
    private enum Header {
        static let id = "x-emb-id"
        static let startTime = "x-emb-st"
    }

    func addEmbraceHeaders() -> URLRequest {
        var mutableRequest = self
        mutableRequest.setValue(UUID().uuidString,
                                forHTTPHeaderField: Header.id)
        mutableRequest.setValue(Date().serializedInterval.description,
                                forHTTPHeaderField: Header.startTime)
        return mutableRequest
    }
}
