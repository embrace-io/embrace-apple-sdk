//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Class used to add attachments when creating `EmbraceLogs`.
@objc
public class EmbraceLogAttachment: NSObject {

    @objc public let id: String
    @objc public let data: Data?
    @objc public let url: URL?

    /// Creates a new `EmbraceLogAttachment` with the given `Data`.
    /// Use this method to upload attachments that are hosted by Embrace.
    /// - Parameter data: The attachment data
    @objc public init(data: Data) {
        self.id = EmbraceIdentifier.random.stringValue
        self.data = data
        self.url = nil
    }
    
    /// Creates a new `EmbraceLogAttachment` with the given `URL`.
    /// Use this method for attachment data that is hosted outisde of Embrace.
    /// - Parameters:
    ///   - id: Identifier of the attachment
    ///   - url: Download url for th attachment data
    @objc public init(id: String, url: URL) {
        self.id = id
        self.data = nil
        self.url = url
    }
}
