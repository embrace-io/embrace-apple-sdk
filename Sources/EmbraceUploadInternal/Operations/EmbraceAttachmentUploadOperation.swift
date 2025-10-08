//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class EmbraceAttachmentUploadOperation: EmbraceUploadOperation, @unchecked Sendable {

    override func createRequest(
        endpoint: URL,
        data: Data,
        identifier: String,
        metadataOptions: EmbraceUpload.MetadataOptions
    ) -> URLRequest {

        let boundary = UUID().uuidString

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        addHeaders(to: &request)

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var multiPartData = Data()

        // app_id
        multiPartData.appendString("--\(boundary)\r\n")
        multiPartData.appendString("Content-Disposition: form-data; name=\"app_id\"\r\n")
        multiPartData.appendString("Content-Type: text/plain\r\n")
        multiPartData.appendString("\r\n")
        multiPartData.appendString(metadataOptions.apiKey)
        multiPartData.appendString("\r\n")

        // attachment_id
        multiPartData.appendString("--\(boundary)\r\n")
        multiPartData.appendString("Content-Disposition: form-data; name=\"attachment_id\"\r\n")
        multiPartData.appendString("Content-Type: text/plain\r\n")
        multiPartData.appendString("\r\n")
        multiPartData.appendString(identifier)
        multiPartData.appendString("\r\n")

        // data
        multiPartData.appendString("--\(boundary)\r\n")
        multiPartData.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(identifier)\"\r\n")
        multiPartData.appendString("\r\n")
        multiPartData.append(data)
        multiPartData.appendString("\r\n")

        multiPartData.appendString("--\(boundary)--")

        request.httpBody = multiPartData

        return request
    }
}

extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
