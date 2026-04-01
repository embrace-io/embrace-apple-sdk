//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Class used to add attachments when creating `EmbraceLogs`.
public class EmbraceLogAttachment {

    public let id: String
    public let data: Data?
    public let url: URL?

    /// Creates a new `EmbraceLogAttachment` with the given `Data`.
    /// Use this method to upload attachments that are hosted by Embrace.
    /// - Parameter data: The attachment data
    public init(data: Data) {
        self.id = UUID().withoutHyphen
        self.data = data
        self.url = nil
    }

    /// Creates a new `EmbraceLogAttachment` with the given `URL`.
    /// Use this method for attachment data that is hosted outisde of Embrace.
    /// - Parameters:
    ///   - id: Identifier of the attachment
    ///   - url: Download url for th attachment data
    public init(id: String, url: URL) {
        self.id = id
        self.data = nil
        self.url = url
    }
}
