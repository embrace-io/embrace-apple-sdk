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

    /// Contains all the session ids posted in order from first posted to last.
    private(set) var postedJsonsSessionIds: [String] = []

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

        if !postedJsonsSessionIds.contains(sessionId) {
            postedJsonsSessionIds.append(sessionId)
        }

        NotificationCenter.default.post(name: NSNotification.Name("NetworkingSwizzle.CapturedNewPayload"), object: nil)
    }

    private func capturedExportedSpan(_ spanExporter: TestSpanExporter) {
        var currentSessionId: String? = nil

        if let sessionSpan = spanExporter.latestExporterSpans.first (where: { span in
            span.name == "emb-session"
        }) {
            currentSessionId = sessionSpan.attributes["session.id"]?.description
        } else {
            currentSessionId = Embrace.client?.currentSessionId()
        }

        guard let currentSessionId = currentSessionId else {
            return
        }

        exportedSpansBySession[currentSessionId, default:[]].append(contentsOf: spanExporter.latestExporterSpans)
    }

    private func capturedExportedLog(_ logExporter: TestLogRecordExporter) {
        guard let currentSessionId = Embrace.client?.currentSessionId() else {
            return
        }

        exportedLogsBySessions[currentSessionId, default:[]].append(contentsOf: logExporter.latestExportedLogs)
    }
}
