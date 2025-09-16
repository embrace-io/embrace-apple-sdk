//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultOTelSignalsHandlerTests: XCTestCase {

    var handler: DefaultOTelSignalsHandler!
    var sessionController: MockSessionController!
    var logController: LogController!
    var limiter: MockOTelSignalsLimiter!
    var sanitizer: MockOTelSignalsSanitizier!
    var bridge: MockOTelSignalBridge!
    var storage: EmbraceStorage!
    var upload: SpyEmbraceLogUploader!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        upload = SpyEmbraceLogUploader()

        sessionController = MockSessionController()
        sessionController.storage = storage

        logController = LogController(
            storage: storage,
            upload: upload,
            sessionController: sessionController,
            queue: .main
        )

        limiter = MockOTelSignalsLimiter()
        sanitizer = MockOTelSignalsSanitizier()
        bridge = MockOTelSignalBridge()

        handler = DefaultOTelSignalsHandler(
            storage: storage,
            sessionController: sessionController,
            logController: logController,
            limiter: limiter,
            sanitizer: sanitizer,
            bridge: bridge
        )

        sessionController.spanHandler = handler
        sessionController.startSession(state: .foreground)
    }

    override func tearDownWithError() throws {
        storage = nil
        upload = nil
        sessionController = nil
        logController = nil
        limiter = nil
        sanitizer = nil
        bridge = nil
        handler = nil
    }

    // MARK: createSpan
    func test_createSpan_success() throws {
        // given a handler
        // when creating a span
        let parent = MockSpan(name: "parent")
        let startTime = Date(timeIntervalSince1970: 1)
        let endTime = Date(timeIntervalSince1970: 2)
        let event = EmbraceSpanEvent(name: "event")
        let link = EmbraceSpanLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)

        let span = try handler.createSpan(
            name: "test",
            parentSpan: parent,
            type: .performance,
            status: .ok,
            startTime: startTime,
            endTime: endTime,
            events: [event],
            links: [link],
            attributes: ["key": "value"]
        )

        // then the right calls are made
        XCTAssertEqual(limiter.shouldCreateCustomSpanCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeSpanNameCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeSpanAttributesCallCount, 1)
        XCTAssertEqual(bridge.startSpanCallCount, 1)

        // then the span has the correct values
        XCTAssertEqual(span.name, "test")
        XCTAssertEqual(span.parentSpanId, parent.context.spanId)
        XCTAssertEqual(span.type, .performance)
        XCTAssertEqual(span.status, .ok)
        XCTAssertEqual(span.startTime, startTime)
        XCTAssertEqual(span.endTime, endTime)
        XCTAssertEqual(span.events[0].name, "event")
        XCTAssertEqual(span.links[0].context.spanId, TestConstants.spanId)
        XCTAssertEqual(span.links[0].context.traceId, TestConstants.traceId)
        XCTAssertEqual(span.attributes["key"], "value")
        XCTAssertTrue(span is DefaultEmbraceSpan)

        // then the span has the correct internal attributes
        XCTAssertEqual(span.attributes["emb.type"], "perf")
        XCTAssertEqual(span.attributes["session.id"], sessionController.currentSession!.id.stringValue)

        // then the span is saved in storage correctly
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.name, "test")
        XCTAssertEqual(record!.parentSpanId, parent.context.spanId)
        XCTAssertEqual(record!.type, .performance)
        XCTAssertEqual(record!.status, .ok)
        XCTAssertEqual(record!.startTime, startTime)
        XCTAssertEqual(record!.endTime, endTime)
        XCTAssertEqual(record!.events[0].name, "event")
        XCTAssertEqual(record!.links[0].context.spanId, TestConstants.spanId)
        XCTAssertEqual(record!.links[0].context.traceId, TestConstants.traceId)
        XCTAssertEqual(record!.attributes["key"], "value")
        XCTAssertEqual(record!.attributes["emb.type"], "perf")
        XCTAssertEqual(record!.attributes["session.id"], sessionController.currentSession!.id.stringValue)
    }

    func test_createSpan_failure() throws {
        // given a handler
        // when creating a span that would break the limit
        limiter.shouldCreateCustomSpanReturnValue = false

        XCTAssertThrowsError(try handler.createSpan(name: "test")) { error in

            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -2)
            XCTAssertEqual(limiter.shouldCreateCustomSpanCallCount, 1)
            XCTAssertEqual(sanitizer.sanitizeSpanNameCallCount, 0)
            XCTAssertEqual(sanitizer.sanitizeSpanAttributesCallCount, 0)
            XCTAssertEqual(bridge.startSpanCallCount, 0)

            // and no span is added to the storage
            let spans = storage.fetchSpans(for: sessionController.currentSession!)
            XCTAssertEqual(spans.count, 0)
        }
    }

    func test_createSpan_sanitizeName() throws {
        // given a handler
        // when creating a span with a name that has to be sanitized
        sanitizer.sanitizeSpanNameReturnValue = "sanitized"
        let span = try handler.createSpan(name: "test")

        // then the name is sanitized
        XCTAssertEqual(span.name, "sanitized")
    }

    func test_createSpan_sanitizeAttributes() throws {
        // given a handler
        // when creating a span with attributes that have to be sanitized
        sanitizer.sanitizeSpanAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]
        let span = try handler.createSpan(name: "test", attributes: ["key": "value"])

        // then the attributes are sanitized
        XCTAssertEqual(span.attributes["key"], nil)
        XCTAssertEqual(span.attributes["sanitizedKey"], "sanitizedValue")
    }

    func test_createSpan_attributeCollision() throws {
        // given a handler
        // when creating a span passing attributes
        // that would collide with internal ones
        let span = try handler.createSpan(name: "test", attributes: ["session.id": "test", "emb.type": "test"])

        // then the correct internal attributes are kept
        XCTAssertEqual(span.attributes["session.id"], sessionController.currentSession!.id.stringValue)
        XCTAssertEqual(span.attributes["emb.type"], "perf")
    }

    func test_createSpan_autoTermination() throws {
        // given a handler
        // when creating a span with an auto termination code
        let span = try handler.createSpan(name: "test", autoTerminationCode: .userAbandon)

        // when the session ends and the auto termination is triggered
        handler.autoTerminateSpans()

        // then the span is automatically terminated with the correct code
        XCTAssertEqual(span.status, .error)
        XCTAssertNotNil(span.endTime)
        XCTAssertEqual(span.attributes["emb.error_code"], "user_abandon")
    }

    func test_createSpan_autoTermination_parentCode() throws {
        // given a handler
        // when creating a parent span with an auto termination code
        // and a child span with no auto termination code
        let parentSpan = try handler.createSpan(name: "parent", autoTerminationCode: .userAbandon)
        let span = try handler.createSpan(name: "child", parentSpan: parentSpan)

        // when the session ends and the auto termination is triggered
        handler.autoTerminateSpans()

        // then both spans are automatically terminated with the correct code
        XCTAssertEqual(parentSpan.status, .error)
        XCTAssertNotNil(parentSpan.endTime)
        XCTAssertEqual(parentSpan.attributes["emb.error_code"], "user_abandon")

        XCTAssertEqual(span.status, .error)
        XCTAssertNotNil(span.endTime)
        XCTAssertEqual(span.attributes["emb.error_code"], "user_abandon")
    }

    // MARK: addSessionEvent
    func test_addSessionEvent_success() throws {
        // given a handler
        // when adding a new session event
        let timestamp = Date(timeIntervalSince1970: 5)
        try handler.addSessionEvent(name: "test", type: .lowPower, timestamp: timestamp, attributes: ["key": "value"])

        // then the right calls are made
        XCTAssertEqual(limiter.shouldAddSessionEventCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeSpanEventNameCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeSpanEventAttributesCallCount, 1)
        XCTAssertEqual(bridge.addSpanEventCallCount, 1)

        // then the event is added correctly
        let span = sessionController.currentSessionSpan!
        XCTAssertEqual(span.events.count, 1)
        XCTAssertEqual(span.events[0].name, "test")
        XCTAssertEqual(span.events[0].type, .lowPower)
        XCTAssertEqual(span.events[0].timestamp, timestamp)
        XCTAssertEqual(span.events[0].attributes["emb.type"], "sys.low_power")
        XCTAssertEqual(span.events[0].attributes["key"], "value")

        // then the event is saved correctly
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        XCTAssertEqual(record.events.count, 1)
        XCTAssertEqual(record.events[0].name, "test")
        XCTAssertEqual(record.events[0].type, .lowPower)
        XCTAssertEqual(record.events[0].timestamp, timestamp)
        XCTAssertEqual(record.events[0].attributes["emb.type"], "sys.low_power")
        XCTAssertEqual(record.events[0].attributes["key"], "value")
    }

    func test_addSessionEvent_failure_noSession() throws {
        // given a handler
        // when adding a new session event when there's no session active
        let spanId = sessionController.currentSessionSpan!.context.spanId
        let traceId = sessionController.currentSessionSpan!.context.traceId
        sessionController.endSession()

        XCTAssertThrowsError(try handler.addSessionEvent(name: "test")) { error in

            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -1)
            XCTAssertEqual(limiter.shouldAddSessionEventCallCount, 0)
            XCTAssertEqual(sanitizer.sanitizeSpanEventNameCallCount, 0)
            XCTAssertEqual(sanitizer.sanitizeSpanEventAttributesCallCount, 0)
            XCTAssertEqual(bridge.addSpanEventCallCount, 0)

            // and no event is added to the storage
            let span = storage.fetchSpan(id: spanId, traceId: traceId)
            XCTAssertEqual(span!.events.count, 0)
        }
    }

    func test_addSessionEvent_failure_limit() throws {
        // given a handler
        // when adding a new session event that would break the limit
        limiter.shouldAddSessionEventReturnValue = false

        XCTAssertThrowsError(try handler.addSessionEvent(name: "test")) { error in

            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -3)
            XCTAssertEqual(limiter.shouldAddSessionEventCallCount, 1)
            XCTAssertEqual(sanitizer.sanitizeSpanEventNameCallCount, 0)
            XCTAssertEqual(sanitizer.sanitizeSpanEventAttributesCallCount, 0)
            XCTAssertEqual(bridge.addSpanEventCallCount, 0)

            // and no event is added to the storage
            let spanId = sessionController.currentSessionSpan!.context.spanId
            let traceId = sessionController.currentSessionSpan!.context.traceId
            let span = storage.fetchSpan(id: spanId, traceId: traceId)
            XCTAssertEqual(span!.events.count, 0)
        }
    }

    func test_addSessionEvent_sanitizeName() throws {
        // given a handler
        // when adding a new session event with a name that has to be sanitized
        sanitizer.sanitizeSpanEventNameReturnValue = "sanitized"
        try handler.addSessionEvent(name: "test")

        // then the name is sanitized
        let span = sessionController.currentSessionSpan!
        XCTAssertEqual(span.events[0].name, "sanitized")
    }

    func test_addSessionEvent_sanitizeAttributes() throws {
        // given a handler
        // when adding a new session event with attributes that have to be sanitized
        sanitizer.sanitizeSpanEventAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]
        try handler.addSessionEvent(name: "test", attributes: ["key": "value"])

        // then the attributes are sanitized
        let span = sessionController.currentSessionSpan!
        XCTAssertEqual(span.events[0].attributes["key"], nil)
        XCTAssertEqual(span.events[0].attributes["sanitizedKey"], "sanitizedValue")
    }

    func test_addSessionEvent_attributeCollision() throws {
        // given a handler
        // when adding a new session event span passing attributes
        // that would collide with internal ones
        try handler.addSessionEvent(name: "test", type: .performance, attributes: ["emb.type": "test"])

        // then the correct internal attributes are kept
        let span = sessionController.currentSessionSpan!
        XCTAssertEqual(span.events[0].attributes["emb.type"], "perf")
    }

    // MARK: log
    func test_log_success() throws {
        // given a handler
        // when creating a log
        let timestamp = Date(timeIntervalSince1970: 5)
        try handler.log(
            "test",
            severity: .debug,
            type: .message,
            timestamp: timestamp,
            attributes: ["key": "value"]
        )

        // then the right calls are made
        XCTAssertEqual(limiter.shouldCreateLogCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeLogAttributesCallCount, 1)

        // then the log is created correctly
        wait(timeout: .defaultTimeout) {
            let log = self.logController.batcher.batch!.logs[0]

            return log.body == "test" && log.severity == .debug && log.type == .message && log.timestamp == timestamp && log.attributes["key"] == "value" && log.attributes["emb.type"] == "sys.log"
                && log.attributes["emb.state"] == "foreground" && log.attributes["session.id"] == self.sessionController.currentSession!.id.stringValue && self.bridge.createLogCallCount == 1
        }

        // then the log is saved correctly
        wait(timeout: .defaultTimeout) {
            let record = self.storage.fetchAllLogs()[0]

            return record.body == "test" && record.severity == .debug && record.type == .message && record.timestamp == timestamp && record.attributes["key"] == "value"
                && record.attributes["emb.type"] == "sys.log" && record.attributes["emb.state"] == "foreground"
                && record.attributes["session.id"] == self.sessionController.currentSession!.id.stringValue
        }
    }

    func test_log_failure() throws {
        // given a handler
        // when creating a log that would break the limit
        limiter.shouldCreateLogReturnValue = false

        XCTAssertThrowsError(try handler.log("test", severity: .info)) { error in

            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -6)
            XCTAssertEqual(limiter.shouldCreateLogCallCount, 1)
            XCTAssertEqual(sanitizer.sanitizeLogAttributesCallCount, 0)
            XCTAssertEqual(bridge.createLogCallCount, 0)

            // and no log is created
            wait(delay: .shortTimeout)
            if let batch = logController.batcher.batch {
                XCTAssertEqual(batch.logs.count, 0)
            }
            XCTAssertEqual(storage.fetchAllLogs().count, 0)
        }
    }

    func test_log_sanitizeAttributes() throws {
        // given a handler
        // when creating a log with attributes that have to be sanitized
        sanitizer.sanitizeLogAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]
        try handler.log("test", severity: .info, attributes: ["key": "value"])

        // then the attributes are sanitized
        // then the log is created correctly
        wait(timeout: .defaultTimeout) {
            let log = self.logController.batcher.batch!.logs[0]

            return log.attributes["key"] == nil && log.attributes["sanitizedKey"] == "sanitizedValue"
        }
    }

    func test_log_attributeCollision() throws {
        // given a handler
        // when creating a log passing attributes
        // that would collide with internal ones
        try handler.log(
            "test", severity: .info,
            attributes: [
                "emb.type": "test",
                "session.id": "test",
                "emb.state": "test"
            ])

        // then the correct internal attributes are kept
        wait(timeout: .defaultTimeout) {
            let log = self.logController.batcher.batch!.logs[0]

            return log.attributes["emb.type"] == "sys.log" && log.attributes["session.id"] == self.sessionController.currentSession!.id.stringValue && log.attributes["emb.state"] == "foreground"
        }
    }

    // MARK: attachments
    func test_log_embraceHostedAttachment_success() throws {
        // given a handler
        // when creating a log with an attachment (data)
        try handler.log("test", severity: .info, attachment: EmbraceLogAttachment(data: TestConstants.data))

        // then the correct internal attributes are set
        wait(timeout: .defaultTimeout) {
            let log = self.logController.batcher.batch!.logs[0]

            return log.attributes["emb.attachment_id"] != nil && log.attributes["emb.attachment_size"] == "4" && log.attributes["emb.attachment_error_code"] == nil
        }
    }

    func test_log_embraceHostedAttachment_limit() throws {
        // given a handler
        // when creating a log with an attachment (data) that would break the limit
        sessionController.attachmentCount = 9999
        try handler.log("test", severity: .info, attachment: EmbraceLogAttachment(data: TestConstants.data))

        // then the correct internal attributes are set
        wait(timeout: .defaultTimeout) {
            let log = self.logController.batcher.batch!.logs[0]

            return log.attributes["emb.attachment_id"] != nil && log.attributes["emb.attachment_size"] == "4" && log.attributes["emb.attachment_error_code"] == "OVER_MAX_ATTACHMENTS"

        }
    }

    func test_log_embraceHostedAttachment_tooLarge() throws {
        // given a handler
        // when creating a log with an attachment (data) that is too large
        var str = ""
        for _ in 1...1_048_600 {
            str += "."
        }

        try handler.log("test", severity: .info, attachment: EmbraceLogAttachment(data: str.data(using: .utf8)!))

        // then the correct internal attributes are set
        wait(timeout: .defaultTimeout) {
            let log = self.logController.batcher.batch!.logs[0]

            return log.attributes["emb.attachment_id"] != nil && log.attributes["emb.attachment_size"] == "1048600" && log.attributes["emb.attachment_error_code"] == "ATTACHMENT_TOO_LARGE"

        }
    }

    func test_log_preHostedAttachment_success() throws {
        // given a handler
        // when creating a log with an attachment (data)
        let url = URL(string: "www.test.com")!
        try handler.log("test", severity: .info, attachment: EmbraceLogAttachment(id: "test", url: url))

        // then the correct internal attributes are set
        wait(timeout: .defaultTimeout) {
            let log = self.logController.batcher.batch!.logs[0]

            return log.attributes["emb.attachment_id"] == "test" && log.attributes["emb.attachment_url"] == url.absoluteString && log.attributes["emb.attachment_size"] == nil
                && log.attributes["emb.attachment_error_code"] == nil
        }
    }

    // MARK: stack traces
    func test_log_defaultStackTrace() throws {
        // given a handler
        // when creating a non-warn/error log with default stack trace
        try handler.log("test", severity: .info, stackTraceBehavior: .default)

        // then the stack trace is not added
        wait(delay: .defaultTimeout)
        XCTAssertNil(logController.batcher.batch!.logs[0].attributes["emb.stacktrace.ios"])
    }

    func test_warnLog_defaultStackTrace() throws {
        // given a handler
        // when creating a warn log with default stack trace
        try handler.log("test", severity: .warn, stackTraceBehavior: .default)

        // then the stack trace is added
        wait(delay: .defaultTimeout)
        XCTAssertNotNil(logController.batcher.batch!.logs[0].attributes["emb.stacktrace.ios"])
    }

    func test_errorLog_defaultStackTrace() throws {
        // given a handler
        // when creating a error log with default stack trace
        try handler.log("test", severity: .error, stackTraceBehavior: .default)

        // then the stack trace is added
        wait(delay: .defaultTimeout)
        XCTAssertNotNil(logController.batcher.batch!.logs[0].attributes["emb.stacktrace.ios"])
    }

    let customFrames = [
        "0   Page_Contents                       0x000000010af45dec main + 136",
        "1   ExecutionExtension                  0x00000001002a7e24 ExecutionExtension + 32292"
    ]

    func test_log_customStackTrace() throws {
        // given a handler
        // when creating a non-warn/error log with custom stack trace
        let stackTrace = try EmbraceStackTrace(frames: customFrames)
        try handler.log("test", severity: .info, stackTraceBehavior: .custom(stackTrace))

        // then the stack trace is not added
        wait(delay: .defaultTimeout)
        XCTAssertNil(logController.batcher.batch!.logs[0].attributes["emb.stacktrace.ios"])
    }

    func test_warnLog_customStackTrace() throws {
        // given a handler
        // when creating a warn log with custom stack trace
        let stackTrace = try EmbraceStackTrace(frames: customFrames)
        try handler.log("test", severity: .warn, stackTraceBehavior: .custom(stackTrace))

        // then the stack trace is added
        wait(delay: .defaultTimeout)
        XCTAssertNotNil(logController.batcher.batch!.logs[0].attributes["emb.stacktrace.ios"])
    }

    func test_errorLog_customStackTrace() throws {
        // given a handler
        // when creating a error log with custom stack trace
        let stackTrace = try EmbraceStackTrace(frames: customFrames)
        try handler.log("test", severity: .error, stackTraceBehavior: .custom(stackTrace))

        // then the stack trace is added
        wait(delay: .defaultTimeout)
        XCTAssertNotNil(logController.batcher.batch!.logs[0].attributes["emb.stacktrace.ios"])
    }

    func test_log_noStackTrace() throws {
        // given a handler
        // when creating a non-warn/error log with no stack trace
        try handler.log("test", severity: .info, stackTraceBehavior: .notIncluded)

        // then the stack trace is not added
        wait(delay: .defaultTimeout)
        XCTAssertNil(logController.batcher.batch!.logs[0].attributes["emb.stacktrace.ios"])
    }

    func test_warnLog_noStackTrace() throws {
        // given a handler
        // when creating a warn log with no stack trace
        try handler.log("test", severity: .warn, stackTraceBehavior: .notIncluded)

        // then the stack trace is not added
        wait(delay: .defaultTimeout)
        XCTAssertNil(logController.batcher.batch!.logs[0].attributes["emb.stacktrace.ios"])
    }

    func test_errorLog_noStackTrace() throws {
        // given a handler
        // when creating a error log with no stack trace
        try handler.log("test", severity: .error, stackTraceBehavior: .notIncluded)

        // then the stack trace is not added
        wait(delay: .defaultTimeout)
        XCTAssertNil(logController.batcher.batch!.logs[0].attributes["emb.stacktrace.ios"])
    }
}
