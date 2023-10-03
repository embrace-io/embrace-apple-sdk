//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    class EndpointOptions {
        /// URL for the sessions upload endpoint
        public var sessionsURL: URL

        /// URL for the blobs upload endpoint
        public var blobsURL: URL

        public init(sessionsURL: URL, blobsURL: URL) {
            self.sessionsURL = sessionsURL
            self.blobsURL = blobsURL
        }
    }
}
