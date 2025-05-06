//
//  NetworkingSwizzle.swift
//  EmbraceIOTestApp
//
//

import Foundation
import OpenTelemetrySdk
import EmbraceCommonInternal
import EmbraceCore

class NetworkingSwizzle: NSObject {
    private typealias URLSessionCompletion = (Data?, URLResponse?, Error?) -> Void
    private typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, URLSessionCompletion?) -> URLSessionDataTask
    private typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, URLSessionCompletion?) -> URLSessionDataTask

    weak var spanExporter: TestSpanExporter?
    weak var logExporter: TestLogRecordExporter?

    static private var initialized = false

    private(set) var capturedJsons: [String: [NSDictionary]] = [:]
    private var exportedSpansBySession: [String: [SpanData]] = [:]
    private var exportedLogsBySessions: [String: [ReadableLogRecord]] = [:]

    init(spanExporter: TestSpanExporter, logExporter: TestLogRecordExporter) {
        super.init()
        self.spanExporter = spanExporter
        self.logExporter = logExporter
        do { try setup() } catch {}
    }

    private func setup() throws {
        guard !NetworkingSwizzle.initialized else { return }

        NetworkingSwizzle.initialized = true

        let selector: Selector = #selector(
            URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping URLSessionCompletion) -> URLSessionDataTask
        )

        guard let method = class_getInstanceMethod(URLSession.self, selector) else { return }
        let originalImp = method_getImplementation(method)

        let newImplementationBlock: BlockImplementationType = { urlSession, urlRequest, completion -> URLSessionDataTask in
            let originalMethod = unsafeBitCast(originalImp, to: ImplementationType.self)
            if let data = urlRequest.httpBody {
                if let uncompressed = try? data.gunzipped() {
                    if let json = try? JSONSerialization.jsonObject(with: uncompressed) as? NSDictionary {
                        self.capturedNewJson(json)
                    }
                }
            }
            let task = originalMethod(urlSession, selector, urlRequest, completion)
            return task
        }
        let newImplementation = imp_implementationWithBlock(newImplementationBlock)
        method_setImplementation(method, newImplementation)

        NotificationCenter.default.addObserver(forName: .init("TestSpanExporter.SpansUpdated"), object: nil, queue: nil) { [weak self] _ in
            guard
                let self = self,
                let spanExporter = self.spanExporter
            else { return }
            self.capturedExportedSpan(spanExporter)
        }

        NotificationCenter.default.addObserver(forName: .init("TestLogRecordExporter.LogsUpdated"), object: nil, queue: nil) { [weak self] _ in
            guard
                let self = self,
                let logExporter = self.logExporter
            else { return }
            self.capturedExportedLog(logExporter)
        }
    }

    private func capturedNewJson(_ json: NSDictionary) {
        guard let currentSessionId = Embrace.client?.currentSessionId() else {
            return
        }

        if self.capturedJsons[currentSessionId] == nil {
            self.capturedJsons[currentSessionId] = [json]
        } else {
            self.capturedJsons[currentSessionId]?.append(json)
        }
    }

    private func capturedExportedSpan(_ spanExporter: TestSpanExporter) {
        guard let currentSessionId = Embrace.client?.currentSessionId() else {
            return
        }

        if exportedSpansBySession[currentSessionId] == nil {
            exportedSpansBySession[currentSessionId] = spanExporter.latestExporterSpans
        } else {
            exportedSpansBySession[currentSessionId]?.append(contentsOf: spanExporter.latestExporterSpans)
        }
    }

    private func capturedExportedLog(_ logExporter: TestLogRecordExporter) {
        guard let currentSessionId = Embrace.client?.currentSessionId() else {
            return
        }

        if exportedLogsBySessions[currentSessionId] == nil {
            exportedLogsBySessions[currentSessionId] = logExporter.latestExportedLogs
        } else {
            exportedLogsBySessions[currentSessionId]?.append(contentsOf: logExporter.latestExportedLogs)
        }
    }
}
