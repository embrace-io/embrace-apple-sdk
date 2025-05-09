//
//  NetworkingSwizzle.swift
//  EmbraceIOTestApp
//
//

import Foundation
import OpenTelemetrySdk
import EmbraceCommonInternal
import EmbraceCore

typealias JsonDictionary = Dictionary<String, Any>

class NetworkingSwizzle: NSObject {
    private typealias URLSessionCompletion = (Data?, URLResponse?, Error?) -> Void
    private typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, URLSessionCompletion?) -> URLSessionDataTask
    private typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, URLSessionCompletion?) -> URLSessionDataTask

    weak var spanExporter: TestSpanExporter?
    weak var logExporter: TestLogRecordExporter?

    static private var initialized = false

    /// Contains all Jsons posted, separated by Session Id
    private(set) var postedJsons: Dictionary<String, Array<JsonDictionary>> = [:]

    /// Contains all exported spans grouped by the Session they were exported on. Including the session span. The Key is the Session Id.
    private(set) var exportedSpansBySession: Dictionary<String, [SpanData]> = [:]

    /// Contains all the logs exported, grouped by Session Id.
    private(set) var exportedLogsBySessions: [String: [ReadableLogRecord]] = [:]

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
                    if let json = try? JSONSerialization.jsonObject(with: uncompressed) as? Dictionary<String, Any> {
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

    private func capturedNewJson(_ json: Dictionary<String, Any>) {
        let data = json["data"] as? Dictionary<String, Any> ?? [:]
        let spans = data["spans"] as? Array<Dictionary<String, Any>> ?? []
        let sessionSpan = spans.first { $0["name"] as? String == "emb-session" }
        let attributes = sessionSpan?["attributes"] as? Array<Dictionary<String, String>>
        let sessionIdAttribute = attributes?.first { $0["key"] == "session.id" }
        let sessionId = sessionIdAttribute?["value"] as? String

        guard let sessionId = sessionId else {
            return
        }

        self.postedJsons[sessionId, default: []].append(json)

        UploadedSessionPayloadTest().test(networkSwizzle: self)
    }

    private func capturedExportedSpan(_ spanExporter: TestSpanExporter) {
        var currentSessionId: String? = Embrace.client?.currentSessionId()
        if currentSessionId == nil {
            let sessionSpan = spanExporter.latestExporterSpans.first { span in
                span.attributes["emb.type"]?.description == "ux.session"
            }
            currentSessionId = sessionSpan?.attributes["session.id"]?.description
        }

        guard let currentSessionId = currentSessionId else {
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

class UploadedSessionPayloadTest: NSObject {
    func test(networkSwizzle: NetworkingSwizzle) {
        let exportedSpansSessionIds = networkSwizzle.exportedSpansBySession.keys
        guard exportedSpansSessionIds.count > 0 else {
            return
        }

        let postedSessionIds = networkSwizzle.postedJsons.keys

        postedSessionIds.forEach { sessionId in
            print(sessionId)
            let exportedSpans = networkSwizzle.exportedSpansBySession[sessionId]
            exportedSpans?.forEach { exportedSpan in
                let postedJsons = networkSwizzle.postedJsons[sessionId]
                var foundSpans = 0
                var missingSpans = 0
                postedJsons?.forEach { postedJson in
                    let data = postedJson["data"] as? JsonDictionary
                    let postedSpans = data?["spans"] as? Array<JsonDictionary>
                    let span = postedSpans?.first { $0["span_id"] as? String == exportedSpan.spanId.hexString }
                    if span != nil {
                        //print("found span: \(exportedSpan.spanId.hexString)")
                        foundSpans += 1
                    } else {
                        print("MISSING span: \(exportedSpan.spanId.hexString)")
                        print("-- Span Name: \(exportedSpan.name)")
                        print("-- Span type: \(exportedSpan.embType)")
                        missingSpans += 1
                    }
                }
            }
        }

        // Making sure all exported spans were posted
        let allFound = Set(exportedSpansSessionIds).isSubset(of: postedSessionIds)

        if allFound {
            print("All sessions were posted")
        } else {
            print("some sessions were not posted")
        }


    }
}
