//
//  DataCollector.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

@Observable class DataCollector: NSObject {
    private(set) var logExporter = TestLogRecordExporter()
    private(set) var spanExporter = TestSpanExporter()
    private(set) var networkSpy: NetworkingSwizzle?

    init(setupSwizzles: Bool = false) {
        super.init()
        if setupSwizzles {
            self.networkSpy = NetworkingSwizzle(spanExporter: self.spanExporter, logExporter: self.logExporter)
        }
    }
}
