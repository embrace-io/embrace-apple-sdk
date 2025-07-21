//
//  NetworkingSwizzle.swift
//  EmbraceIOTestApp
//
//

import EmbraceCommonInternal
import EmbraceConfigInternal
import EmbraceCore
import EmbraceOTelInternal
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

typealias JsonDictionary = [String: Any]

class NetworkingSwizzle: NSObject {
    typealias URLSessionCompletion = (Data?, URLResponse?, Error?) -> Void

    weak var spanExporter: TestSpanExporter?
    weak var logExporter: TestLogRecordExporter?

    static private var initialized = false

    /// Contains all Jsons posted, separated by Session Id
    private(set) var postedJsons: [String: [JsonDictionary]] = [:]

    /// Contains all the session ids posted in order from first posted to last.
    private(set) var postedJsonsSessionIds: [String] = []

    /// Contains all exported spans grouped by the Session they were exported on. Including the session span. The Key is the Session Id.
    private(set) var exportedSpansBySession: [String: [SpanData]] = [:]

    /// Contains all the logs exported, grouped by Session Id.
    private(set) var exportedLogsBySessions: [String: [ReadableLogRecord]] = [:]

    /// For whatever reason, some tasks get lost in the ether so their completion handlers are never called.
    /// A quick fix is to just keep a reference to them here... Not ideal but this is a test app not intended to run for too long.
    /// Will consider making a cleaning routine if necessary. For now, this will do.
    private var createdTasks: [MockDataTask] = []

    init(spanExporter: TestSpanExporter, logExporter: TestLogRecordExporter) {
        super.init()
        self.spanExporter = spanExporter
        self.logExporter = logExporter
        setup()
    }

    var simulateEmbraceAPI: Bool = true

    private func setup() {
        guard !NetworkingSwizzle.initialized else { return }

        NetworkingSwizzle.initialized = true

        setupDataTaskWithCompletionHandler()

        setupNotifications()
    }

    private func setupDataTaskWithCompletionHandler() {
        typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, URLSessionCompletion?) ->
            URLSessionDataTask
        typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, URLSessionCompletion?) ->
            URLSessionDataTask

        let selector: Selector = #selector(
            URLSession.dataTask(with:completionHandler:)
                as (URLSession) -> (URLRequest, @escaping URLSessionCompletion) -> URLSessionDataTask
        )

        guard let method = class_getInstanceMethod(URLSession.self, selector) else { return }
        let originalImp = method_getImplementation(method)

        let newImplementationBlock: BlockImplementationType = {
            urlSession, urlRequest, completion -> URLSessionDataTask in
            let originalMethod = unsafeBitCast(originalImp, to: ImplementationType.self)
            if let data = urlRequest.httpBody {
                if let uncompressed = try? data.gunzipped() {
                    if let json = try? JSONSerialization.jsonObject(with: uncompressed) as? [String: Any] {
                        self.capturedNewJson(json)
                    }
                }
            }

            if self.simulateEmbraceAPI {
                if self.isConfigRequest(urlRequest) {
                    let task = MockDataTask(
                        originalRequest: urlRequest, completionData: MockData.mockConfig, completion: completion)
                    self.createdTasks.append(task)
                    return task
                }

                if self.isEmbraceApiRequest(urlRequest) {
                    let task = MockDataTask(originalRequest: urlRequest, completion: completion)
                    self.createdTasks.append(task)
                    return task
                }
            }

            let task = originalMethod(urlSession, selector, urlRequest, completion)
            return task

        }
        let newImplementation = imp_implementationWithBlock(newImplementationBlock)
        method_setImplementation(method, newImplementation)
    }

    private func isConfigRequest(_ urlRequest: URLRequest) -> Bool {
        guard urlRequest.httpMethod == "GET" else { return false }
        guard urlRequest.url?.pathComponents.contains("config") ?? false else { return false }

        return true
    }

    private func isEmbraceApiRequest(_ urlRequest: URLRequest) -> Bool {
        guard urlRequest.url?.pathComponents.contains("api") ?? false else { return false }
        guard urlRequest.url?.pathComponents.contains("v2") ?? false else { return false }

        return true
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: .init("TestSpanExporter.SpansUpdated"), object: nil, queue: nil)
        {
            [weak self] _ in
            guard
                let self = self,
                let spanExporter = self.spanExporter
            else { return }
            self.capturedExportedSpan(spanExporter)
        }

        NotificationCenter.default.addObserver(
            forName: .init("TestLogRecordExporter.LogsUpdated"), object: nil, queue: nil
        ) { [weak self] _ in
            guard
                let self = self,
                let logExporter = self.logExporter
            else { return }
            self.capturedExportedLog(logExporter)
        }
    }

    private func capturedNewJson(_ json: [String: Any]) {
        let data = json["data"] as? [String: Any] ?? [:]
        let spans = data["spans"] as? [[String: Any]] ?? []
        let sessionSpan = spans.first { $0["name"] as? String == "emb-session" }
        let attributes = sessionSpan?["attributes"] as? [[String: String]]
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

        if let sessionSpan = spanExporter.latestExporterSpans.first(where: { span in
            span.name == "emb-session"
        }) {
            currentSessionId = sessionSpan.attributes["session.id"]?.description
        } else {
            currentSessionId = Embrace.client?.currentSessionId()
        }

        guard let currentSessionId = currentSessionId else {
            return
        }

        exportedSpansBySession[currentSessionId, default: []].append(contentsOf: spanExporter.latestExporterSpans)
    }

    private func capturedExportedLog(_ logExporter: TestLogRecordExporter) {
        guard let currentSessionId = Embrace.client?.currentSessionId() else {
            return
        }

        exportedLogsBySessions[currentSessionId, default: []].append(contentsOf: logExporter.latestExportedLogs)
    }
}
