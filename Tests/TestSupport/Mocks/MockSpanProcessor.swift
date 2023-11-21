//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel

public class MockSpanProcessor: EmbraceSpanProcessor {

    private(set) public var startedSpans = [SpanData]()
    private(set) public var endedSpans = [SpanData]()
    private(set) public var isShutdown = false

    public init() { }

    public func onStart(span: ExportableSpan) {
        startedSpans.append(span.spanData)
    }

    public func onEnd(span: ExportableSpan) {
        endedSpans.append(span.spanData)
    }

    public func shutdown() {
        isShutdown = true
    }

}
