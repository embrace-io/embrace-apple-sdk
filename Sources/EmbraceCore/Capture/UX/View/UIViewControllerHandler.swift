//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import OpenTelemetryApi
import EmbraceCaptureService
import EmbraceOTelInternal
import EmbraceCommonInternal
import EmbraceSemantics

protocol UIViewControllerHandlerDataSource: AnyObject {
    var state: CaptureServiceState { get }
    var otel: EmbraceOpenTelemetry? { get }

    var instrumentVisibility: Bool { get }
    var instrumentFirstRender: Bool { get }
}

class UIViewControllerHandler {

    weak var dataSource: UIViewControllerHandlerDataSource?
    private let queue: DispatchableQueue = DispatchQueue(label: "com.embrace.UIViewControllerHandler", qos: .utility)

    @ThreadSafe var parentSpans: [String: Span] = [:]
    @ThreadSafe var viewDidLoadSpans: [String: Span] = [:]
    @ThreadSafe var viewWillAppearSpans: [String: Span] = [:]
    @ThreadSafe var viewDidAppearSpans: [String: Span] = [:]
    @ThreadSafe var visibilitySpans: [String: Span] = [:]

    @ThreadSafe var uiReadySpans: [String: Span] = [:]
    @ThreadSafe var alreadyFinishedUiReadyIds: Set<String> = []

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func parentSpan(for vc: UIViewController) -> Span? {
        guard let id = vc.emb_identifier else {
            return nil
        }

        return parentSpans[id]
    }

    @objc func appDidEnterBackground() {
        // end all parent spans and visibility spans if the app enters the background
        // also clear all the cached spans
        queue.async {
            for span in self.visibilitySpans.values {
                span.end()
            }

            for id in self.parentSpans.keys {
                self.forcefullyEndSpans(id: id)
            }

            self.parentSpans.removeAll()
            self.viewDidLoadSpans.removeAll()
            self.viewWillAppearSpans.removeAll()
            self.viewDidAppearSpans.removeAll()
            self.visibilitySpans.removeAll()
            self.uiReadySpans.removeAll()
            self.alreadyFinishedUiReadyIds.removeAll()
        }
    }

    func onViewDidLoadStart(_ vc: UIViewController) {

        guard dataSource?.state == .active,
              dataSource?.instrumentFirstRender == true,
              vc.emb_shouldCaptureView,
              let otel = dataSource?.otel else {
            return
        }

        queue.async {
            // generate id
            let id = UUID().uuidString
            vc.emb_identifier = id

            // generate parent span
            let className = vc.className

            // check if with need to measure time-to-render or time-to-interactive
            let nameFormat = vc is InteractableViewController ?
                SpanSemantics.View.timeToInteractiveName :
                SpanSemantics.View.timeToFirstRenderName

            let spanName = nameFormat.replacingOccurrences(of: "NAME", with: className)

            let parentSpan = self.createSpan(
                with: otel,
                vc: vc,
                name: spanName
            )

            // generate view did load span
            let viewDidLoadSpan = self.createSpan(
                with: otel,
                vc: vc,
                name: SpanSemantics.View.viewDidLoadName,
                parent: parentSpan
            )

            self.parentSpans[id] = parentSpan
            self.viewDidLoadSpans[id] = viewDidLoadSpan
        }
    }

    func onViewDidLoadEnd(_ vc: UIViewController) {
        queue.async {
            guard let id = vc.emb_identifier,
                  let span = self.viewDidLoadSpans[id] else {
                return
            }

            span.end()
            self.viewDidLoadSpans[id] = nil
        }
    }

    func onViewWillAppearStart(_ vc: UIViewController) {
        queue.async {
            guard let otel = self.dataSource?.otel,
                  let id = vc.emb_identifier,
                  let parentSpan = self.parentSpans[id] else {
                return
            }

            // generate view will appear span
            let span = self.createSpan(
                with: otel,
                vc: vc,
                name: SpanSemantics.View.viewWillAppearName,
                parent: parentSpan
            )

            self.viewWillAppearSpans[id] = span
        }
    }

    func onViewWillAppearEnd(_ vc: UIViewController) {
        queue.async {
            guard let id = vc.emb_identifier,
                  let span = self.viewWillAppearSpans[id] else {
                return
            }

            span.end()
            self.viewWillAppearSpans[id] = nil
        }
    }

    func onViewDidAppearStart(_ vc: UIViewController) {
        queue.async {
            guard let otel = self.dataSource?.otel,
                  let id = vc.emb_identifier,
                  let parentSpan = self.parentSpans[id] else {
                return
            }

            // generate view did appear span
            let span = self.createSpan(
                with: otel,
                vc: vc,
                name: SpanSemantics.View.viewDidAppearName,
                parent: parentSpan
            )

            self.viewDidAppearSpans[id] = span
        }
    }

    func onViewDidAppearEnd(_ vc: UIViewController) {
        queue.async {
            guard let otel = self.dataSource?.otel else {
                return
            }

            // check if we need to create a visibility span
            if self.dataSource?.instrumentVisibility == true {
                // create id if necessary
                let id = vc.emb_identifier ?? UUID().uuidString
                vc.emb_identifier = id

                let span = self.createSpan(
                    with: otel,
                    vc: vc,
                    name: SpanSemantics.View.screenName,
                    type: .view
                )
                self.visibilitySpans[id] = span
            }

            guard let id = vc.emb_identifier else {
                return
            }

            // end view did appear span
            if let span = self.viewDidAppearSpans[id] {
                span.end()
                self.viewDidAppearSpans[id] = nil
            }

            
            guard let parentSpan = self.parentSpans[id] else {
                return
            }

            // end time to first render span
            if parentSpan.isTimeToFirstRender {
                parentSpan.end()
                self.clear(id: id, vc: vc)

            // generate ui ready span
            } else {
                let span = self.createSpan(
                    with: otel,
                    vc: vc,
                    name: SpanSemantics.View.uiReadyName,
                    parent: parentSpan
                )

                // if the view controller was already flagged as ready to interact
                // we end the spans right away
                if self.alreadyFinishedUiReadyIds.contains(id) {
                    span.end()
                    parentSpan.end()

                    self.clear(id: id, vc: vc)

                // otherwise we save it to close it later
                } else {
                    self.uiReadySpans[id] = span
                }
            }
        }
    }

    func onViewDidDisappear(_ vc: UIViewController) {
        queue.async {
            guard let id = vc.emb_identifier else {
                return
            }

            // end visibility span
            if let span = self.visibilitySpans[id] {
                span.end()
            }

            // force end all spans
            self.forcefullyEndSpans(id: id)
        }
    }

    func onViewBecameInteractive(_ vc: UIViewController) {
        queue.async {
            guard let id = vc.emb_identifier,
                  let parentSpan = self.parentSpans[id],
                  parentSpan.isTimeToInteractive else {
                return
            }

            // if we have a ui ready span it means that viewDidAppear already happened
            // in this case we close the spans
            if let span = self.uiReadySpans[id] {
                span.end()
                parentSpan.end()
                self.clear(id: id, vc: vc)

            // otherwise it means the view is still loading, in this case we flag
            // the view controller so we can close the spans as soon as
            // viewDidAppear ends
            } else {
                self.alreadyFinishedUiReadyIds.insert(id)
            }
        }
    }

    private func forcefullyEndSpans(id: String) {

        if let viewDidLoadSpan = self.viewDidLoadSpans[id] {
            viewDidLoadSpan.end(errorCode: .userAbandon)
        }

        if let viewWillAppearSpan = self.viewWillAppearSpans[id] {
            viewWillAppearSpan.end(errorCode: .userAbandon)
        }

        if let viewDidAppearSpan = self.viewDidAppearSpans[id] {
            viewDidAppearSpan.end(errorCode: .userAbandon)
        }

        if let uiReadySpan = self.uiReadySpans[id] {
            uiReadySpan.end(errorCode: .userAbandon)
        }

        if let parentSpan = self.parentSpans[id] {
            parentSpan.end(errorCode: .userAbandon)
        }

        self.clear(id: id)
    }

    private func createSpan(
        with otel: EmbraceOpenTelemetry,
        vc: UIViewController,
        name: String,
        type: SpanType = .viewLoad,
        parent: Span? = nil
    ) -> Span {
        let builder = otel.buildSpan(
            name: name,
            type: .viewLoad,
            attributes: [
                SpanSemantics.View.keyViewTitle: vc.emb_viewName,
                SpanSemantics.View.keyViewName: vc.className
            ])

        if let parent = parent {
            builder.setParent(parent)
        }

        return builder.startSpan()
    }

    private func clear(id: String, vc: UIViewController? = nil) {
        self.parentSpans[id] = nil
        self.viewDidLoadSpans[id] = nil
        self.viewWillAppearSpans[id] = nil
        self.viewDidAppearSpans[id] = nil
        self.visibilitySpans[id] = nil
        self.uiReadySpans[id] = nil
        self.alreadyFinishedUiReadyIds.remove(id)

        vc?.emb_identifier = nil
    }
}

extension Span {
    var isTimeToFirstRender: Bool {
        return name.contains("time-to-first-render")
    }

    var isTimeToInteractive: Bool {
        return name.contains("time-to-interactive")
    }
}

#endif
