import XCTest
@testable import EmbraceCore
import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport
import EmbraceOTelInternal
import OpenTelemetryApi
import OpenTelemetrySdk

final class EmbraceTraceViewLoggerTests: XCTestCase {
    
    var spanProcessor: MockSpanProcessor!
    var phase: EmbraceTraceViewLogger!
    
    override func setUpWithError() throws {
        spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessors: [spanProcessor])
        phase = EmbraceTraceViewLogger(otel: MockEmbraceOpenTelemetry(), logger: MockLogger(), config: MockEmbraceConfigurable(isSwiftUiViewInstrumentationEnabled: true))
    }
    
    override func tearDownWithError() throws {
        spanProcessor = nil
        EmbraceOTel.setup(spanProcessors: [])
        phase = nil
    }
}
