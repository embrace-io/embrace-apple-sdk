//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    class EndpointOptions {
        /// URL for the spans upload endpoint
        public let spansURL: URL

        /// URL for the blobs upload endpoint
        public let blobsURL: URL

        /// URL for the logs upload endpoint
        public let logsURL: URL

        public init(spansURL: URL, blobsURL: URL, logsURL: URL) {
            self.spansURL = spansURL
            self.blobsURL = blobsURL
            self.logsURL = logsURL
        }
    }
}
