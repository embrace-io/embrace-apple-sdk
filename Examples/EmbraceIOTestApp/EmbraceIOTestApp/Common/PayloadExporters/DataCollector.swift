//
//  DataCollector.swift
//  EmbraceIOTestApp
//
//  Created by Fernando Draghi on 30/04/2025.
//

import SwiftUI
import OpenTelemetrySdk

@Observable class DataCollector: NSObject {
    private(set) var logExporter = TestLogRecordExporter()
    private(set) var spanExporter = TestSpanExporter()
    private(set) var networkSpy = NetworkingSwizzle()
}
