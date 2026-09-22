//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

class DataGzipTests: XCTestCase {

    func test_gzipRoundTrip_largeMultiChunkPayload() throws {
        // given a payload larger than the internal chunk buffer (exercises the multi-chunk deflate/inflate loop)
        let original = Data((0..<200_000).map { UInt8($0 % 251) })

        // when gzipping it
        let compressed = try original.gzipped()

        // then the result is gzip-framed and differs from the input
        XCTAssertTrue(compressed.isGzipped)
        XCTAssertNotEqual(compressed, original)

        // and gunzipping restores the original bytes
        XCTAssertEqual(try compressed.gunzipped(), original)
    }

    func test_gzipped_emptyData_returnsEmpty() throws {
        // empty input is a no-op in both directions (and must not crash)
        XCTAssertEqual(try Data().gzipped(), Data())
        XCTAssertEqual(try Data().gunzipped(), Data())
    }

    func test_gunzipped_corruptData_throwsDataError() throws {
        // given bytes that are not valid gzip/zlib
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x12, 0x34, 0x56, 0x78])

        // when gunzipping, then it throws a GzipError with the data-corruption kind
        XCTAssertThrowsError(try garbage.gunzipped()) { error in
            guard let gzipError = error as? GzipError else {
                return XCTFail("expected GzipError, got \(error)")
            }
            XCTAssertEqual(gzipError.kind, .data)
        }
    }

    func test_gzipped_inputExceedingMaxSize_throwsMemoryError() throws {
        // given data larger than the allowed max input size
        let data = Data(repeating: 0xAB, count: 1024)

        // when gzipping with a smaller cap, then it throws a GzipError with the memory kind
        XCTAssertThrowsError(try data.gzipped(maxInputSize: 512)) { error in
            guard let gzipError = error as? GzipError else {
                return XCTFail("expected GzipError, got \(error)")
            }
            XCTAssertEqual(gzipError.kind, .memory)
        }
    }
}
