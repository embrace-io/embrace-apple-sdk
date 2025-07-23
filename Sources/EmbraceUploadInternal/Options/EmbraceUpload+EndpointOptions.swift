//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension EmbraceUpload {
    public class EndpointOptions {
        /// URL for the spans upload endpoint
        public let spansURL: URL

        /// URL for the logs upload endpoint
        public let logsURL: URL

        /// URL for the attachments upload endpoint
        public let attachmentsURL: URL

        public init(spansURL: URL, logsURL: URL, attachmentsURL: URL) {
            self.spansURL = spansURL
            self.logsURL = logsURL
            self.attachmentsURL = attachmentsURL
        }
    }
}
