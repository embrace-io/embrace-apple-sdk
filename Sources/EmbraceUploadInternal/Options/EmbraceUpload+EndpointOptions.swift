//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    class EndpointOptions {
        /// URL for the spans upload endpoint
        public let spansURL: URL

        /// URL for the logs upload endpoint
        public let logsURL: URL

        public init(spansURL: URL, logsURL: URL) {
            self.spansURL = spansURL
            self.logsURL = logsURL
        }
    }
}
