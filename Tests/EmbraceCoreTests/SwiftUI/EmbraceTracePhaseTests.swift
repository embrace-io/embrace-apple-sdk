import XCTest
@testable import EmbraceCore
import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport
import EmbraceOTelInternal
import OpenTelemetryApi
import OpenTelemetrySdk

final class EmbraceTracePhaseTests: XCTestCase {
    
    var spanProcessor: MockSpanProcessor!
    var phase: EmbraceTracePhase!
    
    override func setUpWithError() throws {
        spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessors: [spanProcessor])
        phase = EmbraceTracePhase(otel: MockEmbraceOpenTelemetry(), logger: MockLogger())
    }
    
    override func tearDownWithError() throws {
        spanProcessor = nil
        EmbraceOTel.setup(spanProcessors: [])
        phase = nil
    }
}
