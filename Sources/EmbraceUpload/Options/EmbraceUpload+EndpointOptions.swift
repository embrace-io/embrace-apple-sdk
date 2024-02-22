//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    class EndpointOptions {
        /// URL for the sessions upload endpoint
        public let sessionsURL: URL

        /// URL for the blobs upload endpoint
        public let blobsURL: URL

        /// URL for the logs upload endpoint
        public let logsURL: URL

        public init(sessionsURL: URL, blobsURL: URL, logsURL: URL) {
            self.sessionsURL = sessionsURL
            self.blobsURL = blobsURL
            self.logsURL = logsURL
        }
    }
}
