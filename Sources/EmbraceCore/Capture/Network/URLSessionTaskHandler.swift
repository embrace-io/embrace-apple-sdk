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

protocol URLSessionTaskHandler: AnyObject {
    @discardableResult
    func create(task: URLSessionTask) -> Bool
    func finish(task: URLSessionTask, data: Data?, error: (any Error)?)
}

protocol URLSessionTaskHandlerDataSource: AnyObject {
    var state: CaptureServiceState { get }
    var otel: EmbraceOpenTelemetry? { get }

    var injectTracingHeader: Bool { get }
    var requestsDataSource: URLSessionRequestsDataSource? { get }
}

final class DefaultURLSessionTaskHandler: URLSessionTaskHandler {

    private var spans: [URLSessionTask: Span] = [:]
    private let queue: DispatchQueue
    weak var dataSource: URLSessionTaskHandlerDataSource?

    init(processingQueue: DispatchQueue = DefaultURLSessionTaskHandler.queue(),
         dataSource: URLSessionTaskHandlerDataSource?) {
        self.queue = processingQueue
        self.dataSource = dataSource
    }

    @discardableResult
    func create(task: URLSessionTask) -> Bool {

        var handled = false

        queue.sync {
            // don't capture if the service is not active
            guard self.dataSource?.state == .active else {
                return
            }

            // don't capture if this task was already handled
            guard task.embraceCaptured == false else {
                return
            }

            guard
                var request = task.originalRequest,
                let url = request.url,
                let otel = self.dataSource?.otel else {
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
                attributes: attributes
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

    func finish(task: URLSessionTask, data: Data?, error: (any Error)?) {
        queue.async {
            guard self.dataSource?.state == .active else {
                return
            }

            guard let span = self.spans.removeValue(forKey: task) else {
                return
            }

            if let response = task.response as? HTTPURLResponse {
                span.setAttribute(
                    key: SpanSemantics.NetworkRequest.keyStatusCode,
                    value: response.statusCode
                )
            }

            if let data = data {
                let totalData = task.embraceData ?? data
                span.setAttribute(
                    key: SpanSemantics.NetworkRequest.keyResponseSize,
                    value: totalData.count
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
    }

    func addTracingHeader(task: URLSessionTask, span: Span) -> String? {

        guard dataSource?.injectTracingHeader == true,
              task.originalRequest != nil else {
            return nil
        }

        // ignore if header is already present
        let headerName = SpanSemantics.NetworkRequest.traceparentHeader

        let previousValue = task.originalRequest?.value(forHTTPHeaderField: headerName)
        guard previousValue == nil else {
            return previousValue
        }

        // set traceparent request header
        // Docs: https://www.w3.org/TR/trace-context-1/#trace-context-http-headers-format
        // Note: Version hardcoded to "00"
        // Note: Flags hardcoded to "01" (means "sampled")
        let value = "00-\(span.context.traceId.hexString)-\(span.context.spanId.hexString)-01"
        if task.injectHeader(withKey: headerName, value: value) {
            return value
        }

        return nil
    }
}

private extension DefaultURLSessionTaskHandler {
    static func queue() -> DispatchQueue {
        .init(label: "com.embrace.URLSessionTaskHandler", qos: .utility)
    }
}
