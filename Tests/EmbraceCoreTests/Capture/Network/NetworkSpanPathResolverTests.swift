//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

class NetworkSpanPathResolverTests: XCTestCase {
    private let baseURL = URL(string: "https://embrace.io/users/12345")!

    // MARK: - resolve(request:url:)

    func test_validHeader_isUsedAsPath() {
        let request = makeRequest(xEmbPath: "/api/users/:id")
        XCTAssertEqual(NetworkSpanPathResolver.resolve(request: request, url: baseURL), "/api/users/:id")
    }

    func test_missingHeader_fallsBackToUrlPath() {
        let request = makeRequest()
        XCTAssertEqual(NetworkSpanPathResolver.resolve(request: request, url: baseURL), "/users/12345")
    }

    func test_emptyHeader_fallsBackToUrlPath() {
        let request = makeRequest(xEmbPath: "")
        XCTAssertEqual(NetworkSpanPathResolver.resolve(request: request, url: baseURL), "/users/12345")
    }

    func test_headerWithoutLeadingSlash_fallsBackToUrlPath() {
        let request = makeRequest(xEmbPath: "api/users/:id")
        XCTAssertEqual(NetworkSpanPathResolver.resolve(request: request, url: baseURL), "/users/12345")
    }

    func test_headerWithQueryString_fallsBackToUrlPath() {
        let request = makeRequest(xEmbPath: "/api/users?foo=bar")
        XCTAssertEqual(NetworkSpanPathResolver.resolve(request: request, url: baseURL), "/users/12345")
    }

    func test_headerWithFragment_fallsBackToUrlPath() {
        let request = makeRequest(xEmbPath: "/api/users#section")
        XCTAssertEqual(NetworkSpanPathResolver.resolve(request: request, url: baseURL), "/users/12345")
    }

    // MARK: - isValid(_:)

    func test_nonAsciiCharacters_isInvalid() {
        XCTAssertFalse(NetworkSpanPathResolver.isValid("/api/üsers"))
    }

    func test_headerOverMaxLength_isInvalid() {
        let longPath = "/" + String(repeating: "a", count: 1024)
        XCTAssertFalse(NetworkSpanPathResolver.isValid(longPath))
    }

    func test_headerAtExactMaxLength_isValid() {
        let path = "/" + String(repeating: "a", count: 1023)
        XCTAssertTrue(NetworkSpanPathResolver.isValid(path))
    }

    func test_validSimplePath_isValid() {
        XCTAssertTrue(NetworkSpanPathResolver.isValid("/api/users/:id"))
    }

    func test_rfc3986SpecialChars_areAccepted() {
        // unreserved: A-Z a-z 0-9 - . _ ~
        // sub-delims: ! $ & ' ( ) * + , ; =
        // pchar extras: : @ /
        XCTAssertTrue(NetworkSpanPathResolver.isValid("/path/with-chars_and.tilde~/:colon@at!dollar$"))
        XCTAssertTrue(NetworkSpanPathResolver.isValid("/a/b(c)*d+e,f;g=h"))
    }

    func test_emptyString_isInvalid() {
        XCTAssertFalse(NetworkSpanPathResolver.isValid(""))
    }

    func test_slashOnly_isValid() {
        XCTAssertTrue(NetworkSpanPathResolver.isValid("/"))
    }

    func test_invalidCharacter_isInvalid() {
        XCTAssertFalse(NetworkSpanPathResolver.isValid("/api/users{id}"))
    }
}

// MARK: - Helpers

private extension NetworkSpanPathResolverTests {
    func makeRequest(xEmbPath: String? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL)
        if let path = xEmbPath {
            request.setValue(path, forHTTPHeaderField: NetworkSpanPathResolver.headerName)
        }
        return request
    }
}
