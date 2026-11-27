import TestSupport
//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
import XCTest

@testable import EmbraceUploadInternal

class EmbraceAttachmentUploadOperationTests: XCTestCase {

    let testMetadataOptions = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )

    var transport: MockUploadTransport!
    var queue: DispatchQueue!

    override func setUpWithError() throws {
        self.transport = MockUploadTransport()
        self.queue = .main
    }

    func test_createRequest() {

        let data = "12345".data(using: .utf8)!
        let attachmentId = "987654321"

        let operation = EmbraceAttachmentUploadOperation(
            transport: transport,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: attachmentId,
            data: data,
            payloadTypes: "test",
            retryCount: 0,
            exponentialBackoffBehavior: .init(),
            attemptCount: 0
        )

        let request = operation.createRequest(
            endpoint: TestConstants.url,
            data: data,
            identifier: attachmentId,
            metadataOptions: testMetadataOptions
        )

        XCTAssert(request.allHTTPHeaderFields!["Content-Type"]!.contains("multipart/form-data;"))
        XCTAssertEqual(request.allHTTPHeaderFields!["User-Agent"], testMetadataOptions.userAgent)
        XCTAssertEqual(request.allHTTPHeaderFields!["X-EM-AID"], testMetadataOptions.apiKey)
        XCTAssertEqual(request.allHTTPHeaderFields!["X-EM-DID"], testMetadataOptions.deviceId)
        XCTAssertEqual(request.allHTTPHeaderFields!["X-EM-PAYLOAD-TYPES"], "test")

        let body = String(data: request.httpBody!, encoding: .utf8)

        // app id
        XCTAssert(body!.contains("Content-Disposition: form-data; name=\"app_id\""))
        XCTAssert(body!.contains(testMetadataOptions.apiKey))

        // attachment id
        XCTAssert(body!.contains("Content-Disposition: form-data; name=\"attachment_id\""))
        XCTAssert(body!.contains(attachmentId))

        // attachment data
        XCTAssert(body!.contains("Content-Disposition: form-data; name=\"file\"; filename=\"987654321\""))
        XCTAssert(body!.contains("12345"))
    }
}
