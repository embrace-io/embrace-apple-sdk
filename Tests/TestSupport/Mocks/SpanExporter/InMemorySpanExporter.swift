//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class InMemorySpanExporter: SpanExporter {
    private let lock = NSLock()

    private var _exportedSpans: [SpanId: SpanData] = [:]
    public var exportedSpans: [SpanId: SpanData] {
        lock.lock()
        defer { lock.unlock() }
        return _exportedSpans
    }

    private var _isShutdown = false
    public var isShutdown: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isShutdown
    }

    private var onExportComplete: (() -> Void)?

    private var onFlush: (() -> Void)?

    public init() {}

    public func onExportComplete(completion: (() -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        self.onExportComplete = completion
    }

    public func onFlush(completion: (() -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        self.onFlush = completion
    }

    public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        lock.lock()
        defer { lock.unlock() }

        spans.forEach { data in
            _exportedSpans[data.spanId] = data
        }

        onExportComplete?()
        return .success
    }

    public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        lock.lock()
        let flush = onFlush
        lock.unlock()

        flush?()
        return .success
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        lock.lock()
        defer { lock.unlock() }
        _isShutdown = true
    }
}
