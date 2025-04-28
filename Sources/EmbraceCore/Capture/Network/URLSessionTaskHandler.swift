//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceObjCUtilsInternal
import EmbraceSemantics

extension Notification.Name {
    static let networkRequestCaptured = Notification.Name("networkRequestCaptured")
}

protocol URLSessionTaskHandlerDataSource: AnyObject {
    var state: CaptureServiceState { get }
    var otel: EmbraceOpenTelemetry? { get }

    var injectTracingHeader: Bool { get }
    var requestsDataSource: URLSessionRequestsDataSource? { get }
    var ignoredURLs: [String] { get }
}

final class DefaultURLSessionTaskHandler: NSObject, URLSessionTaskHandler {
    private var spans: [URLSessionTask: Span] = [:]
    private let queue: DispatchableQueue
    private let capturedDataQueue: DispatchableQueue
    private let payloadCaptureHandler: NetworkPayloadCaptureHandler
    weak var dataSource: URLSessionTaskHandlerDataSource?

    init(processingQueue: DispatchableQueue = DefaultURLSessionTaskHandler.queue(),
         capturedDataQueue: DispatchableQueue = DefaultURLSessionTaskHandler.capturedDataQueue(),
         dataSource: URLSessionTaskHandlerDataSource?) {
        self.queue = processingQueue
        self.capturedDataQueue = capturedDataQueue
        self.dataSource = dataSource
        self.payloadCaptureHandler = NetworkPayloadCaptureHandler(otel: dataSource?.otel)
    }

    @discardableResult
    func create(task: URLSessionTask) -> Bool {

        var handled = false

        queue.sync {
            // don't capture if this task was already handled
            guard task.embraceCaptured == false else {
                return
            }

            // save start time for payload capture
            task.embraceStartTime = Date()

            // don't capture if the service is not active
            guard self.dataSource?.state == .active else {
                return
            }

            // validate task
            guard
                var request = task.originalRequest,
                let url = request.url,
                let otel = self.dataSource?.otel else {
                return
            }

            // check ignored urls
            guard shouldCapture(url: url) else {
                return
            }

            // get modified request from data source
            request = self.dataSource?.requestsDataSource?.modifiedRequest(for: request) ?? request

            // flag as captured
            task.embraceCaptured = true

            // Probably this could be moved to a separate class
            var attributes: [String: String] = [:]
            attributes[SpanSemantics.NetworkRequest.keyUrl] = request.url?.absoluteString ?? "N/A"

            let httpMethod = request.httpMethod ?? ""
            if !httpMethod.isEmpty {
                attributes[SpanSemantics.NetworkRequest.keyMethod] = httpMethod
            }

            /*
             Note: According to the OpenTelemetry specification, the attribute name should be ' {method} {http.route}.
             The `{http.route}` corresponds to the template of the path so it's necessary to understand the templating system being employed.
             For instance, a template for a request such as http://embrace.io/users/12345?hello=world
             would be reported as /users/:userId (or /users/:userId? in other templating system).

             Until a decision is made regarding the method to convey this information and the heuristics to extract it,
             the `.path` method will be utilized temporarily. This approach may introduce higher cardinality on the backend,
             which is less than optimal.
             It will be important to address this in the near future to enhance performance for the backend.

             Additional information can be found at:
             - HTTP Name attribute: https://opentelemetry.io/docs/specs/semconv/http/http-spans/#name
             - HTTP Attributes: https://opentelemetry.io/docs/specs/semconv/attributes-registry/http/
             */
            let name = httpMethod.isEmpty ? url.path : "\(httpMethod) \(url.path)"
            let networkSpan = otel.buildSpan(
                name: name,
                type: .networkRequest,
                attributes: attributes,
                autoTerminationCode: nil
            )

            // This should be modified if we start doing this for streaming tasks.
            if let bodySize = request.httpBody {
                networkSpan.setAttribute(key: SpanSemantics.NetworkRequest.keyBodySize, value: bodySize.count)
            }

            let span = networkSpan.startSpan()
            self.spans[task] = span

            // tracing header
            if let tracingHader = self.addTracingHeader(task: task, span: span) {
                span.setAttribute(key: SpanSemantics.NetworkRequest.keyTracingHeader, value: .string(tracingHader))
            }

            handled = true
        }

        return handled
    }

    func finish(task: URLSessionTask, bodySize: Int, error: (any Error)?) {
        // save end time for payload capture
        let embraceEndTime = Date()

        queue.async {
            // process payload capture
            if self.payloadCaptureHandler.isEnabled() {
                var data: Data?
                self.capturedDataQueue.sync {
                    data = task.embraceData
                }

                self.payloadCaptureHandler.process(
                    request: task.currentRequest ?? task.originalRequest,
                    response: task.response,
                    data: data,
                    error: error,
                    startTime: task.embraceStartTime,
                    endTime: embraceEndTime
                )
            }
        }
    }

    func finish(task: URLSessionTask, data: Data?, error: (any Error)?) {
        // save end time for payload capture
        let embraceEndTime = Date()

        queue.async {
            // process payload capture
            if self.payloadCaptureHandler.isEnabled() {
                // performing this logic to prevent any issues accessing `task.embraceData`
                var capturedData = data
                if capturedData == nil {
                    self.capturedDataQueue.sync {
                        capturedData = task.embraceData
                    }
                }

                self.payloadCaptureHandler.process(
                    request: task.currentRequest ?? task.originalRequest,
                    response: task.response,
                    data: capturedData,
                    error: error,
                    startTime: task.embraceStartTime,
                    endTime: embraceEndTime
                )
            }

            self.handleTaskFinished(task, bodySize: data?.count, error: error)
        }
    }

    private func handleTaskFinished(_ task: URLSessionTask, bodySize: Int?, error: (any Error)?) {
        // stop if the service is disabled
        guard self.dataSource?.state == .active else {
            return
        }

        // stop if there was no span for this task
        guard let span = self.spans.removeValue(forKey: task) else {
            return
        }

        // generate attributes from response
        if let response = task.response as? HTTPURLResponse {
            span.setAttribute(
                key: SpanSemantics.NetworkRequest.keyStatusCode,
                value: response.statusCode
            )
        }

        if let bodySize {
            span.setAttribute(
                key: SpanSemantics.NetworkRequest.keyResponseSize,
                value: bodySize
            )
        }

        if let error = error ?? task.error {
            // Should this be something else?
            let nsError = error as NSError
            span.setAttribute(
                key: SpanSemantics.NetworkRequest.keyErrorType,
                value: nsError.domain
            )
            span.setAttribute(
                key: SpanSemantics.NetworkRequest.keyErrorCode,
                value: nsError.code
            )
            span.setAttribute(
                key: SpanSemantics.NetworkRequest.keyErrorMessage,
                value: error.localizedDescription
            )
        }

        span.end()

        // internal notification with the captured request
        Embrace.notificationCenter.post(name: .networkRequestCaptured, object: task)

    }

    func addData(_ data: Data, dataTask: URLSessionDataTask) {
        if payloadCaptureHandler.isEnabled() {
            capturedDataQueue.sync {
                if var previousData = dataTask.embraceData {
                    previousData.append(data)
                    dataTask.embraceData = previousData
                } else {
                    dataTask.embraceData = data
                }
            }
        }
    }

    func addTracingHeader(task: URLSessionTask, span: Span) -> String? {
        guard dataSource?.injectTracingHeader == true,
              task.originalRequest != nil else {
            return nil
        }

        // ignore if header is already present
        let previousValue = task.originalRequest?.value(forHTTPHeaderField: W3C.traceparentHeaderName)
        guard previousValue == nil else {
            return previousValue
        }

        let value = W3C.traceparent(from: span.context)

        if EMBRURLSessionTaskHeaderInjector.injectHeader(
            withKey: W3C.traceparentHeaderName,
            value: value,
            into: task
        ) {
            return value
        }

        return nil
    }

    func shouldCapture(url: URL) -> Bool {
        guard let list = dataSource?.ignoredURLs else {
            return true
        }

        for str in list {
            if url.absoluteString.contains(str) {
                return false
            }
        }

        return true
    }
}

private extension DefaultURLSessionTaskHandler {
    static func queue() -> DispatchableQueue {
        .with(label: "com.embrace.URLSessionTaskHandler", qos: .utility)
    }

    static func capturedDataQueue() -> DispatchableQueue {
        .with(label: "com.embrace.URLSessionTask.embraceData", qos: .utility)
    }
}
