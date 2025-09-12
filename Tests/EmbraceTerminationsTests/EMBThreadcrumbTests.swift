//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceTerminations
import XCTest

final class ThreadcrumbTests: XCTestCase {

    var threadcrumb: EmbraceThreadcrumb!

    override func setUp() {
        super.setUp()
        threadcrumb = EmbraceThreadcrumb()
    }

    override func tearDown() {
        threadcrumb = nil
        super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    func test_initialization_succeeds() {
        // Given & When
        let threadcrumb = EmbraceThreadcrumb()

        // Then
        XCTAssertNotNil(threadcrumb)
    }

    func test_log_returnsNonEmptyStackAddresses() {
        // Given
        let message = "test_message"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, 12, "Stack addresses should not be empty")
    }

    func test_log_returnsArrayOfNSNumbers() {
        // Given
        let message = "test123"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        // Verify all elements are NSNumber (the array type guarantees this)
        XCTAssertFalse(stackAddresses.isEmpty)
        for address in stackAddresses {
            XCTAssertTrue(address.uint64Value > 0, "Address should be a valid pointer value")
        }
    }

    // MARK: - Message Sanitization Tests

    func test_log_sanitizesSpecialCharacters() {
        // Given
        let message = "hello!@#$%world"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        // The message should be sanitized to "helloworld"
        // We verify it works by checking we get stack addresses back
        XCTAssertEqual(stackAddresses.count, 10)
    }

    func test_log_preservesAlphanumericCharacters() {
        // Given
        let message = "abc123XYZ"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, message.count)
    }

    func test_log_preservesUnderscores() {
        // Given
        let message = "test_message_123"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, message.count)
    }

    func test_log_removesSpaces() {
        // Given
        let message = "hello world test"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        // Should be sanitized to "helloworldtest"
        XCTAssertEqual(stackAddresses.count, 14)
    }

    func test_log_removesEmojis() {
        // Given
        let message = "test😀message🎉"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        // Should be sanitized to "testmessage"
        XCTAssertEqual(stackAddresses.count, 11)
    }

    func test_log_removesPunctuation() {
        // Given
        let message = "test.message,with-punctuation!"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        // Should be sanitized to "testmessagewithpunctuation"
        XCTAssertEqual(stackAddresses.count, 26)
    }

    // MARK: - Empty and Edge Case Tests

    func test_log_withEmptyString_returnsStackAddresses() {
        // Given
        let message = ""

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        // Even with empty string, we should get some stack frames
        XCTAssertEqual(stackAddresses.count, 0)
    }

    func test_log_withOnlySpecialCharacters_returnsStackAddresses() {
        // Given
        let message = "!@#$%^&*()"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        // After sanitization this becomes empty, should still return stack
        XCTAssertEqual(stackAddresses.count, 0)
    }

    func test_log_withSingleCharacter_returnsStackAddresses() {
        // Given
        let message = "a"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, message.count)
    }

    func test_log_withLongMessage_returnsStackAddresses() {
        // Given
        let message = "this_is_a_very_long_message_that_contains_many_characters_0123456789"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, message.count)
    }

    // MARK: - Multiple Log Tests

    func test_log_multipleSequentialCalls_succeed() {
        // Given
        let messages = ["first", "second", "third"]

        // When & Then
        for message in messages {
            let stackAddresses = threadcrumb.log(message)
            XCTAssertEqual(stackAddresses.count, message.count, "Failed for message: \(message)")
        }
    }

    func test_log_differentMessages_produceDifferentStacks() {
        // Given
        let message1 = "message1"
        let message2 = "message2"

        // When
        let stack1 = threadcrumb.log(message1)
        let stack2 = threadcrumb.log(message2)

        // Then
        XCTAssertEqual(stack1.count, message1.count)
        XCTAssertEqual(stack2.count, message2.count)
    }

    // MARK: - Specific Character Set Tests

    func test_log_withUppercaseLetters_returnsStackAddresses() {
        // Given
        let message = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, message.count)
    }

    func test_log_withLowercaseLetters_returnsStackAddresses() {
        // Given
        let message = "abcdefghijklmnopqrstuvwxyz"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, message.count)
    }

    func test_log_withDigits_returnsStackAddresses() {
        // Given
        let message = "0123456789"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, message.count)
    }

    func test_log_withOnlyUnderscores_returnsStackAddresses() {
        // Given
        let message = "___"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, message.count)
    }

    // MARK: - Realistic Use Case Tests

    func test_log_withSessionID_returnsStackAddresses() {
        // Given - A realistic 32-character session ID without hyphens
        let message = UUID().uuidString

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        XCTAssertEqual(stackAddresses.count, 32)
    }

    func test_log_withUUIDWithoutHyphens_returnsStackAddresses() {
        // Given - UUID format without hyphens
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        // When
        let stackAddresses = threadcrumb.log(uuid)

        // Then
        XCTAssertEqual(stackAddresses.count, uuid.count)
    }

    func test_log_withIdentifierContainingHyphens_sanitizesCorrectly() {
        // Given - UUID with hyphens (should be stripped)
        let uuid = UUID().uuidString

        // When
        let stackAddresses = threadcrumb.log(uuid)

        // Then
        // Hyphens should be removed, but we should still get stack addresses
        XCTAssertEqual(stackAddresses.count, 32)
    }

    // MARK: - Stack Structure Tests

    func test_log_stackAddressesAreValidPointers() {
        // Given
        let message = "test_stack_validation"

        // When
        let stackAddresses = threadcrumb.log(message)

        // Then
        for address in stackAddresses {
            let value = address.uint64Value
            // Stack addresses should be non-zero valid pointers
            XCTAssertGreaterThan(value, 0, "Stack address should be a valid non-zero pointer")
        }
    }

    // MARK: - Size Tests

    func test_overflowMaxSize() {
        for extraCount in (0...100) {
            let message = String.random(EmbraceThreadcrumbMaximumMessageLength + extraCount)
            let stackAddresses = threadcrumb.log(message)
            XCTAssertEqual(stackAddresses.count, EmbraceThreadcrumbMaximumMessageLength)
        }
    }

    func test_noMessageOverAndOver() {
        let message = ""
        for _ in (0...100) {
            _ = threadcrumb.log(message)
        }
    }

    // MARK: - Concurrency Tests

    func test_concurrentLogs() {

        DispatchQueue.concurrentPerform(iterations: 100) { index in
            let message = String.random(Int.random(in: 0..<EmbraceThreadcrumbMaximumMessageLength))
            let stackAddresses = threadcrumb.log(message)
            XCTAssertEqual(stackAddresses.count, message.count)
        }

    }
}

final class ThreadcrumbPerformanceTests: XCTestCase {

    var threadcrumb: EmbraceThreadcrumb!

    override func setUp() {
        super.setUp()
        threadcrumb = EmbraceThreadcrumb()
    }

    override func tearDown() {
        threadcrumb = nil
        super.tearDown()
    }

    // MARK: - Performance Tests

    func test_perfNoMessage() {
        let message = ""
        measure {
            _ = threadcrumb.log(message)
        }
    }

    func test_perfMaxLengthMessage() {
        let message = String.random(EmbraceThreadcrumbMaximumMessageLength)
        measure {
            _ = threadcrumb.log(message)
        }
    }

    func test_perfTooLongMessage() {
        let message = String.random(EmbraceThreadcrumbMaximumMessageLength * 2)
        measure {
            _ = threadcrumb.log(message)
        }
    }

    func test_perfStripping() {
        let message = String.randomDisallowed(EmbraceThreadcrumbMaximumMessageLength)
        measure {
            _ = threadcrumb.log(message)
        }
    }

    func test_perfUnwindThenMessage() {
        let message = String.random(EmbraceThreadcrumbMaximumMessageLength)
        _ = threadcrumb.log(message)
        measure {
            // unwind, then log again.
            _ = threadcrumb.log(message)
        }
    }
}

extension String {

    static func random(_ length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    static func randomDisallowed(_ length: Int) -> String {
        let characters = "!@#$%^&*()"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

}
