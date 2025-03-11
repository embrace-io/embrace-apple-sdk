//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import TestSupport
import EmbraceStorageInternal
import EmbraceConfigInternal
import EmbraceConfiguration
import OpenTelemetryApi
import EmbraceCommonInternal

class DefaultInternalLoggerTests: XCTestCase {

    func test_none() {

        let logger = DefaultInternalLogger()
        logger.level = .none

        XCTAssertFalse(logger.trace("trace"))
        XCTAssertFalse(logger.debug("debug"))
        XCTAssertFalse(logger.info("info"))
        XCTAssertFalse(logger.warning("warning"))
        XCTAssertFalse(logger.error("error"))
    }


    func test_trace() {
        let logger = DefaultInternalLogger()
        logger.level = .trace

        XCTAssert(logger.trace("trace"))
        XCTAssert(logger.debug("debug"))
        XCTAssert(logger.info("info"))
        XCTAssert(logger.warning("warning"))
        XCTAssert(logger.error("error"))
    }

    func test_debug() {
        let logger = DefaultInternalLogger()
        logger.level = .debug

        XCTAssertFalse(logger.trace("trace"))
        XCTAssert(logger.debug("debug"))
        XCTAssert(logger.info("info"))
        XCTAssert(logger.warning("warning"))
        XCTAssert(logger.error("error"))
    }

    func test_info() {
        let logger = DefaultInternalLogger()
        logger.level = .info

        XCTAssertFalse(logger.trace("trace"))
        XCTAssertFalse(logger.debug("debug"))
        XCTAssert(logger.info("info"))
        XCTAssert(logger.warning("warning"))
        XCTAssert(logger.error("error"))
    }

    func test_warning() {
        let logger = DefaultInternalLogger()
        logger.level = .warning

        XCTAssertFalse(logger.trace("trace"))
        XCTAssertFalse(logger.debug("debug"))
        XCTAssertFalse(logger.info("info"))
        XCTAssert(logger.warning("warning"))
        XCTAssert(logger.error("error"))
    }

    func test_error() {
        let logger = DefaultInternalLogger()
        logger.level = .error

        XCTAssertFalse(logger.trace("trace"))
        XCTAssertFalse(logger.debug("debug"))
        XCTAssertFalse(logger.info("info"))
        XCTAssertFalse(logger.warning("warning"))
        XCTAssert(logger.error("error"))
    }

    func test_internal_trace() {
        // given "cha logger with limtis
        let otel = MockEmbraceOpenTelemetry()
        let sessionController = MockSessionController()
        let logger = DefaultInternalLogger()
        logger.otel = otel
        logger.limits = InternalLogLimits(trace: 1, debug: 0, info: 0, warning: 0, error: 0)
        logger.sessionController = sessionController

        // given a session started
        sessionController.currentSessionId = TestConstants.sessionId
        sessionController.currentSessionState = SessionState.foreground

        // when sending logs
        logger.trace("trace1")
        logger.trace("trace2")
        logger.debug("debug")
        logger.info("info")
        logger.warning("warning")
        logger.error("error")

        // only the appropiate amount are exported
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string("sys.internal"))
        XCTAssertEqual(otel.logs[0].attributes["emb.state"], .string("foreground"))
        XCTAssertEqual(otel.logs[0].attributes["session.id"], .string(TestConstants.sessionId.toString))
        XCTAssertEqual(otel.logs[0].body?.description, "trace1")
        XCTAssertEqual(otel.logs[0].severity, .trace)
    }

    func test_internal_debug() {
        // given "cha logger with limtis
        let otel = MockEmbraceOpenTelemetry()
        let sessionController = MockSessionController()
        let logger = DefaultInternalLogger()
        logger.otel = otel
        logger.limits = InternalLogLimits(trace: 0, debug: 1, info: 0, warning: 0, error: 0)
        logger.sessionController = sessionController

        // given a session started
        sessionController.currentSessionId = TestConstants.sessionId
        sessionController.currentSessionState = SessionState.foreground

        // when sending logs
        logger.trace("trace")
        logger.debug("debug1")
        logger.debug("debug2")
        logger.info("info")
        logger.warning("warning")
        logger.error("error")

        // only the appropiate amount are exported
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string("sys.internal"))
        XCTAssertEqual(otel.logs[0].attributes["emb.state"], .string("foreground"))
        XCTAssertEqual(otel.logs[0].attributes["session.id"], .string(TestConstants.sessionId.toString))
        XCTAssertEqual(otel.logs[0].body?.description, "debug1")
        XCTAssertEqual(otel.logs[0].severity, .debug)
    }

    func test_internal_info() {
        // given "cha logger with limtis
        let otel = MockEmbraceOpenTelemetry()
        let sessionController = MockSessionController()
        let logger = DefaultInternalLogger()
        logger.otel = otel
        logger.limits = InternalLogLimits(trace: 0, debug: 0, info: 1, warning: 0, error: 0)
        logger.sessionController = sessionController

        // given a session started
        sessionController.currentSessionId = TestConstants.sessionId
        sessionController.currentSessionState = SessionState.foreground

        // when sending logs
        logger.trace("trace")
        logger.debug("debug")
        logger.info("info1")
        logger.info("info2")
        logger.warning("warning")
        logger.error("error")

        // only the appropiate amount are exported
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string("sys.internal"))
        XCTAssertEqual(otel.logs[0].attributes["emb.state"], .string("foreground"))
        XCTAssertEqual(otel.logs[0].attributes["session.id"], .string(TestConstants.sessionId.toString))
        XCTAssertEqual(otel.logs[0].body?.description, "info1")
        XCTAssertEqual(otel.logs[0].severity, .info)
    }

    func test_internal_warning() {
        // given "cha logger with limtis
        let otel = MockEmbraceOpenTelemetry()
        let sessionController = MockSessionController()
        let logger = DefaultInternalLogger()
        logger.otel = otel
        logger.limits = InternalLogLimits(trace: 0, debug: 0, info: 0, warning: 1, error: 0)
        logger.sessionController = sessionController

        // given a session started
        sessionController.currentSessionId = TestConstants.sessionId
        sessionController.currentSessionState = SessionState.foreground

        // when sending logs
        logger.trace("trace")
        logger.debug("debug")
        logger.info("info")
        logger.warning("warning1")
        logger.warning("warning2")
        logger.error("error")

        // only the appropiate amount are exported
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string("sys.internal"))
        XCTAssertEqual(otel.logs[0].attributes["emb.state"], .string("foreground"))
        XCTAssertEqual(otel.logs[0].attributes["session.id"], .string(TestConstants.sessionId.toString))
        XCTAssertEqual(otel.logs[0].body?.description, "warning1")
        XCTAssertEqual(otel.logs[0].severity, .warn)
    }

    func test_internal_error() {
        // given "cha logger with limtis
        let otel = MockEmbraceOpenTelemetry()
        let sessionController = MockSessionController()
        let logger = DefaultInternalLogger()
        logger.otel = otel
        logger.limits = InternalLogLimits(trace: 0, debug: 0, info: 0, warning: 0, error: 1)
        logger.sessionController = sessionController

        // given a session started
        sessionController.currentSessionId = TestConstants.sessionId
        sessionController.currentSessionState = SessionState.foreground

        // when sending logs
        logger.trace("trace")
        logger.debug("debug")
        logger.info("info")
        logger.warning("warning")
        logger.error("error1")
        logger.error("error2")

        // only the appropiate amount are exported
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string("sys.internal"))
        XCTAssertEqual(otel.logs[0].attributes["emb.state"], .string("foreground"))
        XCTAssertEqual(otel.logs[0].attributes["session.id"], .string(TestConstants.sessionId.toString))
        XCTAssertEqual(otel.logs[0].body?.description, "error1")
        XCTAssertEqual(otel.logs[0].severity, .error)
    }

    func test_internal_mixed() {
        // given "cha logger with limtis
        let otel = MockEmbraceOpenTelemetry()
        let sessionController = MockSessionController()
        let logger = DefaultInternalLogger()
        logger.otel = otel
        logger.limits = InternalLogLimits(trace: 2, debug: 3, info: 1, warning: 0, error: 4)
        logger.sessionController = sessionController

        // given a session started
        sessionController.currentSessionId = TestConstants.sessionId
        sessionController.currentSessionState = SessionState.foreground

        // when sending logs
        logger.trace("trace1")
        logger.trace("trace2")
        logger.trace("trace3")
        logger.debug("debug1")
        logger.debug("debug2")
        logger.debug("debug3")
        logger.debug("debug4")
        logger.info("info1")
        logger.info("info2")
        logger.warning("warning")
        logger.error("error1")
        logger.error("error2")
        logger.error("error3")
        logger.error("error4")
        logger.error("error5")

        // only the appropiate amount are exported
        XCTAssertEqual(otel.logs.count, 10)
        XCTAssertEqual(otel.logs.filter({ $0.severity == .trace }).count, 2)
        XCTAssertEqual(otel.logs.filter({ $0.severity == .debug }).count, 3)
        XCTAssertEqual(otel.logs.filter({ $0.severity == .info }).count, 1)
        XCTAssertEqual(otel.logs.filter({ $0.severity == .warn }).count, 0)
        XCTAssertEqual(otel.logs.filter({ $0.severity == .error }).count, 4)
    }
}
