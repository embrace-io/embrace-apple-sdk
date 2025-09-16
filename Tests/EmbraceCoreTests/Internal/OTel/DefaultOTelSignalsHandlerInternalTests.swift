//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultOTelSignalsHandlerInternalTests: XCTestCase {

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

    // MARK: internal APIs
    func test_createInternalSpan() throws {
        // given a handler with limits
        limiter.shouldCreateCustomSpanReturnValue = false
        sanitizer.sanitizeSpanNameReturnValue = "sanitized"
        sanitizer.sanitizeSpanAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]

        // when creating an internal span
        let parent = MockSpan(name: "parent")
        let startTime = Date(timeIntervalSince1970: 1)
        let endTime = Date(timeIntervalSince1970: 2)
        let event = EmbraceSpanEvent(name: "event")
        let link = EmbraceSpanLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)

        let span = try handler.createInternalSpan(
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
        XCTAssertEqual(limiter.shouldCreateCustomSpanCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeSpanNameCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeSpanAttributesCallCount, 0)
        XCTAssertEqual(bridge.startSpanCallCount, 1)

        // then the span is created ignoring the limits
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
        XCTAssertTrue(span is InternalEmbraceSpan)

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

    func test_addInternalSessionEvent() throws {
        // given a handler with limits
        limiter.shouldAddSessionEventReturnValue = false
        sanitizer.sanitizeSpanEventNameReturnValue = "sanitized"
        sanitizer.sanitizeSpanEventAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]

        // when adding a new session event
        let timestamp = Date(timeIntervalSince1970: 5)
        try handler.addInternalSessionEvent(
            name: "test",
            type: .lowPower,
            timestamp: timestamp,
            attributes: ["key": "value"]
        )

        // then the right calls are made
        XCTAssertEqual(limiter.shouldAddSessionEventCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeSpanEventNameCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeSpanEventAttributesCallCount, 0)
        XCTAssertEqual(bridge.addSpanEventCallCount, 1)

        // then the event is created ignoring the limits
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

    func test_internalLog() throws {
        // given a handler with limits
        limiter.shouldCreateLogReturnValue = false
        sanitizer.sanitizeLogAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]

        // when creating a log
        let timestamp = Date(timeIntervalSince1970: 5)
        try handler.internalLog(
            "test",
            severity: .debug,
            type: .message,
            timestamp: timestamp,
            attributes: ["key": "value"]
        )

        // then the right calls are made
        XCTAssertEqual(limiter.shouldCreateLogCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeLogAttributesCallCount, 0)

        // then the log is created ignoring limits
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

    func test_exportLog() throws {
        // given a handler with limits
        limiter.shouldCreateLogReturnValue = false
        sanitizer.sanitizeLogAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]

        // when exporting a log
        let timestamp = Date(timeIntervalSince1970: 5)
        handler.exportLog(
            "test",
            severity: .debug,
            type: .message,
            timestamp: timestamp,
            attributes: ["key": "value"]
        )

        // then the right calls are made
        XCTAssertEqual(limiter.shouldCreateLogCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeLogAttributesCallCount, 0)

        // then the log is forwarded to the bridge without it being added to the batch
        wait(delay: .defaultTimeout)
        XCTAssertNil(logController.batcher.batch)
        XCTAssertEqual(bridge.createLogCallCount, 1)

        // then the log is not saved
        XCTAssertEqual(storage.fetchAllLogs().count, 0)
    }

    // MARK: EmbraceSpanDelegate
    func test_onSpanStatusUpdated() throws {
        // given a span
        let span = MockSpan(name: "test")
        storage?.upsertSpan(span)

        // when onSpanStatusUpdated is called
        handler.onSpanStatusUpdated(span, status: .ok)

        // then the right calls are made
        XCTAssertEqual(bridge.updateSpanStatusCallCount, 1)

        // then the span is updated on the db
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.status, .ok)
    }

    func test_onSpanEventAdded() throws {
        // given a span
        let span = MockSpan(name: "test")
        storage?.upsertSpan(span)

        // when onSpanEventAdded is called
        handler.onSpanEventAdded(span, event: EmbraceSpanEvent(name: "event"))

        // then the right calls are made
        XCTAssertEqual(bridge.addSpanEventCallCount, 1)

        // then the span is updated on the db
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.events.count, 1)
        XCTAssertEqual(record!.events[0].name, "event")
    }

    func test_onSpanLinkAdded() throws {
        // given a span
        let span = MockSpan(name: "test")
        storage?.upsertSpan(span)

        // when onSpanLinkAdded is called
        let link = EmbraceSpanLink(context: EmbraceSpanContext(spanId: TestConstants.spanId, traceId: TestConstants.traceId))
        handler.onSpanLinkAdded(span, link: link)

        // then the right calls are made
        XCTAssertEqual(bridge.addSpanLinkCallCount, 1)

        // then the span is updated on the db
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.links.count, 1)
        XCTAssertEqual(record!.links[0].context.spanId, TestConstants.spanId)
        XCTAssertEqual(record!.links[0].context.traceId, TestConstants.traceId)
    }

    func test_onSpanAttributesUpdated() throws {
        // given a span
        let span = MockSpan(name: "test")
        storage?.upsertSpan(span)

        // when onSpanAttributesUpdated is called
        handler.onSpanAttributesUpdated(span, key: "key", value: "value", attributes: ["key": "value"])

        // then the right calls are made
        XCTAssertEqual(bridge.updateSpanAttributeCallCount, 1)

        // then the span is updated on the db
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.attributes, ["key": "value"])
    }

    func test_onSpanEnded() throws {
        // given a span
        let span = MockSpan(name: "test")
        storage?.upsertSpan(span)

        // when onSpanEnded is called
        let endTime = Date()
        handler.onSpanEnded(span, endTime: endTime)

        // then the right calls are made
        XCTAssertEqual(bridge.endSpanCallCount, 1)

        // then the span is updated on the db
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.endTime, endTime)
    }

    // MARK: EmbraceSpanDataSource
    func test_createEvent_success() throws {
        // given a handler with limits
        sanitizer.sanitizeSpanEventNameReturnValue = "sanitized"
        sanitizer.sanitizeSpanEventAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]

        // when creating an event
        let span = MockSpan(name: "test")
        let timestamp = Date()
        let event = try handler.createEvent(
            for: span,
            name: "event",
            type: .performance,
            timestamp: timestamp,
            attributes: ["key": "value"],
            internalAttributes: ["internalKey": "internalValue"],
            currentCount: 0
        )

        // then the right calls are made
        XCTAssertEqual(limiter.shouldAddSpanEventCallCount, 1)
        XCTAssertEqual(limiter.shouldAddSessionEventCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeSpanEventNameCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeSpanEventAttributesCallCount, 1)

        // then the event is created correctly
        XCTAssertEqual(event.name, "sanitized")
        XCTAssertEqual(event.type, .performance)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes.count, 3)
        XCTAssertEqual(event.attributes["emb.type"], "perf")
        XCTAssertEqual(event.attributes["sanitizedKey"], "sanitizedValue")
        XCTAssertEqual(event.attributes["internalKey"], "internalValue")
    }

    func test_createEvent_failure() throws {
        // given a handler with limits
        limiter.shouldAddSpanEventReturnValue = false

        // when creating an event
        let span = MockSpan(name: "test")
        let timestamp = Date()

        XCTAssertThrowsError(
            try handler.createEvent(
                for: span,
                name: "event",
                type: .performance,
                timestamp: timestamp,
                attributes: ["key": "value"],
                internalAttributes: ["internalKey": "internalValue"],
                currentCount: 0
            )
        ) { error in
            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -3)

            // then the right calls are made
            XCTAssertEqual(limiter.shouldAddSpanEventCallCount, 1)
            XCTAssertEqual(limiter.shouldAddSessionEventCallCount, 0)
            XCTAssertEqual(sanitizer.sanitizeSpanEventNameCallCount, 0)
            XCTAssertEqual(sanitizer.sanitizeSpanEventAttributesCallCount, 0)
        }
    }

    func test_createEvent_attributeCollision() throws {
        // given a handler
        // when creating an event with attributes that would collide with internal ones
        let span = MockSpan(name: "test")
        let timestamp = Date()
        let event = try handler.createEvent(
            for: span,
            name: "event",
            type: .performance,
            timestamp: timestamp,
            attributes: ["internalKey": "value"],
            internalAttributes: ["internalKey": "internalValue"],
            currentCount: 0
        )

        // then the right calls are made
        XCTAssertEqual(limiter.shouldAddSpanEventCallCount, 1)
        XCTAssertEqual(limiter.shouldAddSessionEventCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeSpanEventNameCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeSpanEventAttributesCallCount, 1)

        // then the event is created correctly
        XCTAssertEqual(event.name, "event")
        XCTAssertEqual(event.type, .performance)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes.count, 2)
        XCTAssertEqual(event.attributes["emb.type"], "perf")
        XCTAssertEqual(event.attributes["internalKey"], "internalValue")
    }

    func test_createEvent_session_success() throws {
        // given a handler with limits
        sanitizer.sanitizeSpanEventNameReturnValue = "sanitized"
        sanitizer.sanitizeSpanEventAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]

        // when creating a session event
        let span = MockSpan(name: "test")
        let timestamp = Date()
        let event = try handler.createEvent(
            for: span,
            name: "event",
            type: .performance,
            timestamp: timestamp,
            attributes: ["key": "value"],
            internalAttributes: ["internalKey": "internalValue"],
            currentCount: 0,
            isSessionEvent: true
        )

        // then the right calls are made
        XCTAssertEqual(limiter.shouldAddSpanEventCallCount, 0)
        XCTAssertEqual(limiter.shouldAddSessionEventCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeSpanEventNameCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeSpanEventAttributesCallCount, 1)

        // then the event is created correctly
        XCTAssertEqual(event.name, "sanitized")
        XCTAssertEqual(event.type, .performance)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes.count, 3)
        XCTAssertEqual(event.attributes["emb.type"], "perf")
        XCTAssertEqual(event.attributes["sanitizedKey"], "sanitizedValue")
        XCTAssertEqual(event.attributes["internalKey"], "internalValue")
    }

    func test_createEvent_session_failure() throws {
        // given a handler with limits
        limiter.shouldAddSessionEventReturnValue = false

        // when creating a sesion event
        let span = MockSpan(name: "test")
        let timestamp = Date()

        XCTAssertThrowsError(
            try handler.createEvent(
                for: span,
                name: "event",
                type: .performance,
                timestamp: timestamp,
                attributes: ["key": "value"],
                internalAttributes: ["internalKey": "internalValue"],
                currentCount: 0,
                isSessionEvent: true
            )
        ) { error in
            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -3)

            // then the right calls are made
            XCTAssertEqual(limiter.shouldAddSpanEventCallCount, 0)
            XCTAssertEqual(limiter.shouldAddSessionEventCallCount, 1)
            XCTAssertEqual(sanitizer.sanitizeSpanEventNameCallCount, 0)
            XCTAssertEqual(sanitizer.sanitizeSpanEventAttributesCallCount, 0)
        }
    }

    func test_createLink_success() throws {
        // given a handler with limits
        sanitizer.sanitizeSpanLinkAttributesReturnValue = ["sanitizedKey": "sanitizedValue"]

        // when creating a link
        let span = MockSpan(name: "test")
        let link = try handler.createLink(
            for: span,
            spanId: TestConstants.spanId,
            traceId: TestConstants.traceId,
            attributes: ["key": "value"],
            currentCount: 0
        )

        // then the right calls are made
        XCTAssertEqual(limiter.shouldAddSpanLinkCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeSpanLinkAttributesCallCount, 1)

        // then the event is created correctly
        XCTAssertEqual(link.context.spanId, TestConstants.spanId)
        XCTAssertEqual(link.context.traceId, TestConstants.traceId)
        XCTAssertEqual(link.attributes.count, 1)
        XCTAssertEqual(link.attributes["sanitizedKey"], "sanitizedValue")
    }

    func test_createLink_failure() throws {
        // given a handler with limits
        limiter.shouldAddSpanLinkReturnValue = false

        // when creating a link
        let span = MockSpan(name: "test")

        XCTAssertThrowsError(
            try handler.createLink(
                for: span,
                spanId: TestConstants.spanId,
                traceId: TestConstants.traceId,
                attributes: ["key": "value"],
                currentCount: 0
            )
        ) { error in
            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -4)

            // then the right calls are made
            XCTAssertEqual(limiter.shouldAddSpanLinkCallCount, 1)
            XCTAssertEqual(sanitizer.sanitizeSpanLinkAttributesCallCount, 0)
        }
    }

    func test_validateAttribute_success() throws {
        // given a handler with limits
        sanitizer.sanitizeAttributeKeyReturnValue = "sanitizedKey"
        sanitizer.sanitizeAttributeValueReturnValue = "sanitizedValue"

        // when validating an attribute
        let span = MockSpan(name: "test")
        let attribute = try handler.validateAttribute(for: span, key: "key", value: "value", currentCount: 0)

        // then the right calls are made
        XCTAssertEqual(limiter.shouldAddSpanAttributeCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeAttributeKeyCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeAttributeValueCallCount, 1)

        // then the attribute is correct
        XCTAssertEqual(attribute.0, "sanitizedKey")
        XCTAssertEqual(attribute.1, "sanitizedValue")
    }

    func test_validateAttribute_failure() throws {
        // given a handler with limits
        limiter.shouldAddSpanAttributeReturnValue = false

        // when validating an attribute
        let span = MockSpan(name: "test")

        XCTAssertThrowsError(
            try handler.validateAttribute(
                for: span,
                key: "key",
                value: "value",
                currentCount: 0
            )
        ) { error in
            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -5)

            // then the right calls are made
            XCTAssertEqual(limiter.shouldAddSpanAttributeCallCount, 1)
            XCTAssertEqual(sanitizer.sanitizeAttributeKeyCallCount, 1)
            XCTAssertEqual(sanitizer.sanitizeAttributeValueCallCount, 0)
        }
    }

    func test_validateAttribute_update() throws {
        // given a handler with limits
        limiter.shouldAddSpanAttributeReturnValue = false
        sanitizer.sanitizeAttributeKeyReturnValue = "sanitizedKey"
        sanitizer.sanitizeAttributeValueReturnValue = "sanitizedValue"

        // when validating an attribute in a way that would update the current value
        // and the limit is reached
        let span = MockSpan(name: "test", attributes: ["sanitizedKey": "oldValue"])
        let attribute = try handler.validateAttribute(for: span, key: "sanitizedKey", value: "newValue", currentCount: 0)

        // then the right calls are made
        XCTAssertEqual(limiter.shouldAddSpanAttributeCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeAttributeKeyCallCount, 1)
        XCTAssertEqual(sanitizer.sanitizeAttributeValueCallCount, 1)

        // then the attribute is updated correctly
        XCTAssertEqual(attribute.0, "sanitizedKey")
        XCTAssertEqual(attribute.1, "sanitizedValue")
    }

    func test_validateAttribute_delete() throws {
        // given a handler
        // when validating an attribute that is getting removed
        let span = MockSpan(name: "test")
        let attribute = try handler.validateAttribute(for: span, key: "key", value: nil, currentCount: 0)

        // then the right calls are made
        XCTAssertEqual(limiter.shouldAddSpanAttributeCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeAttributeKeyCallCount, 0)
        XCTAssertEqual(sanitizer.sanitizeAttributeValueCallCount, 0)

        // then the attribute is deleted correctly
        XCTAssertEqual(attribute.0, "key")
        XCTAssertEqual(attribute.1, nil)
    }

    // MARK: EmbraceOTelDelegate
    func test_onStartSpan_insert() throws {
        // given a handler
        // when it receives the callback to start a span
        let startTime = Date(timeIntervalSince1970: 1)

        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            parentSpanId: "parentId",
            name: "test",
            type: .performance,
            status: .ok,
            startTime: startTime,
            endTime: nil,
            events: [EmbraceSpanEvent(name: "event", attributes: ["key": "value"])],
            links: [EmbraceSpanLink(spanId: "linkSpanId", traceId: "linkTraceId", attributes: ["key": "value"])],
            sessionId: TestConstants.sessionId,
            processId: TestConstants.processId,
            attributes: ["key": "value"]
        )
        handler.onStartSpan(span)

        // then the right calls are made
        XCTAssertEqual(limiter.shouldCreateCustomSpanCallCount, 1)

        // then the span is saved correctly
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.context.spanId, TestConstants.spanId)
        XCTAssertEqual(record!.context.traceId, TestConstants.traceId)
        XCTAssertEqual(record!.parentSpanId, "parentId")
        XCTAssertEqual(record!.name, "test")
        XCTAssertEqual(record!.type, .performance)
        XCTAssertEqual(record!.status, .ok)
        XCTAssertEqual(record!.startTime, startTime)
        XCTAssertNil(record!.endTime)
        XCTAssertEqual(record!.events.count, 1)
        XCTAssertEqual(record!.events[0].name, "event")
        XCTAssertEqual(record!.events[0].attributes["emb.type"], "perf")
        XCTAssertEqual(record!.events[0].attributes["key"], "value")
        XCTAssertEqual(record!.links.count, 1)
        XCTAssertEqual(record!.links[0].context.spanId, "linkSpanId")
        XCTAssertEqual(record!.links[0].context.traceId, "linkTraceId")
        XCTAssertEqual(record!.links[0].attributes, ["key": "value"])
        XCTAssertEqual(record!.sessionId, TestConstants.sessionId)
        XCTAssertEqual(record!.processId, TestConstants.processId)
        XCTAssertEqual(record!.attributes, ["key": "value"])
    }

    func test_onStartSpan_limit_noUpdate() throws {
        // given a handler with limits
        limiter.shouldCreateCustomSpanReturnValue = false

        // when it receives the callback to start a span that is not in the db
        let span = MockSpan(name: "test")
        handler.onStartSpan(span)

        // then the right calls are made
        XCTAssertEqual(limiter.shouldCreateCustomSpanCallCount, 1)

        // and no span is added
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertNil(record)
    }

    func test_onStartSpan_limit_update() throws {
        // given a handler with limits
        limiter.shouldCreateCustomSpanReturnValue = false

        // given a span in storage
        let startTime = Date(timeIntervalSince1970: 1)
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            parentSpanId: "parentId",
            name: "test",
            type: .performance,
            status: .ok,
            startTime: startTime,
            endTime: nil,
            events: [EmbraceSpanEvent(name: "event", attributes: ["key": "value"])],
            links: [EmbraceSpanLink(spanId: "linkSpanId", traceId: "linkTraceId", attributes: ["key": "value"])],
            sessionId: TestConstants.sessionId,
            processId: TestConstants.processId,
            attributes: ["key": "value"]
        )
        storage.upsertSpan(span)

        // when receiving the call back to start a span
        // that would break the limits,
        // but the correspondubg span is already on storage
        let endTime = Date(timeIntervalSince1970: 2)
        span.endTime = endTime
        handler.onStartSpan(span)

        // then the right calls are made
        XCTAssertEqual(limiter.shouldCreateCustomSpanCallCount, 1)

        // then the span is updated correctly
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.context.spanId, TestConstants.spanId)
        XCTAssertEqual(record!.context.traceId, TestConstants.traceId)
        XCTAssertEqual(record!.parentSpanId, "parentId")
        XCTAssertEqual(record!.name, "test")
        XCTAssertEqual(record!.type, .performance)
        XCTAssertEqual(record!.status, .ok)
        XCTAssertEqual(record!.startTime, startTime)
        XCTAssertEqual(record!.endTime, endTime)
        XCTAssertEqual(record!.events.count, 1)
        XCTAssertEqual(record!.events[0].name, "event")
        XCTAssertEqual(record!.events[0].attributes["emb.type"], "perf")
        XCTAssertEqual(record!.events[0].attributes["key"], "value")
        XCTAssertEqual(record!.links.count, 1)
        XCTAssertEqual(record!.links[0].context.spanId, "linkSpanId")
        XCTAssertEqual(record!.links[0].context.traceId, "linkTraceId")
        XCTAssertEqual(record!.links[0].attributes, ["key": "value"])
        XCTAssertEqual(record!.sessionId, TestConstants.sessionId)
        XCTAssertEqual(record!.processId, TestConstants.processId)
        XCTAssertEqual(record!.attributes, ["key": "value"])
    }

    func test_onEndSpan_existing() throws {
        // given a handler
        // given a span in storage
        let startTime = Date(timeIntervalSince1970: 1)
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            parentSpanId: "parentId",
            name: "test",
            type: .performance,
            status: .ok,
            startTime: startTime,
            endTime: nil,
            events: [EmbraceSpanEvent(name: "event", attributes: ["key": "value"])],
            links: [EmbraceSpanLink(spanId: "linkSpanId", traceId: "linkTraceId", attributes: ["key": "value"])],
            sessionId: TestConstants.sessionId,
            processId: TestConstants.processId,
            attributes: ["key": "value"]
        )
        storage.upsertSpan(span)

        // when receiving the call back to end the span
        let endTime = Date(timeIntervalSince1970: 2)
        span.endTime = endTime
        handler.onEndSpan(span)

        // then the span is updated correctly
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.context.spanId, TestConstants.spanId)
        XCTAssertEqual(record!.context.traceId, TestConstants.traceId)
        XCTAssertEqual(record!.parentSpanId, "parentId")
        XCTAssertEqual(record!.name, "test")
        XCTAssertEqual(record!.type, .performance)
        XCTAssertEqual(record!.status, .ok)
        XCTAssertEqual(record!.startTime, startTime)
        XCTAssertEqual(record!.endTime, endTime)
        XCTAssertEqual(record!.events.count, 1)
        XCTAssertEqual(record!.events[0].name, "event")
        XCTAssertEqual(record!.events[0].attributes["emb.type"], "perf")
        XCTAssertEqual(record!.events[0].attributes["key"], "value")
        XCTAssertEqual(record!.links.count, 1)
        XCTAssertEqual(record!.links[0].context.spanId, "linkSpanId")
        XCTAssertEqual(record!.links[0].context.traceId, "linkTraceId")
        XCTAssertEqual(record!.links[0].attributes, ["key": "value"])
        XCTAssertEqual(record!.sessionId, TestConstants.sessionId)
        XCTAssertEqual(record!.processId, TestConstants.processId)
        XCTAssertEqual(record!.attributes, ["key": "value"])
    }

    func test_onEndSpan_notFound() throws {
        // given a handler
        // when receiving the call back to end a span
        // that is not on the db
        let span = MockSpan(name: "test", endTime: Date())
        handler.onEndSpan(span)

        // then no span is added or updated
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertNil(record)
    }

    func test_onEmitLog() throws {
        // given a handler
        // when receiving the call back to emit a log
        let log = MockLog()
        handler.onEmitLog(log)

        // then the right calls are made
        XCTAssertEqual(limiter.shouldCreateLogCallCount, 1)

        // then the log is added to the batch and saved correctly
        wait(delay: .defaultTimeout)
        XCTAssertEqual(logController.batcher.batch!.logs.count, 1)
        XCTAssertEqual(storage.fetchAllLogs().count, 1)
    }

    func test_onEmitLog_limit() throws {
        // given a handler with limits
        limiter.shouldCreateLogReturnValue = false

        // when receiving the call back to emit a log that would break the limit
        let log = MockLog()
        handler.onEmitLog(log)

        // then the right calls are made
        XCTAssertEqual(limiter.shouldCreateLogCallCount, 1)

        // then the log is not added to the batch nor saved
        wait(delay: .defaultTimeout)
        XCTAssertNil(logController.batcher.batch)
        XCTAssertEqual(storage.fetchAllLogs().count, 0)
    }
}
