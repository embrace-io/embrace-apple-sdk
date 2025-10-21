//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import UIKit
    import OpenTelemetryApi
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCaptureService
        import EmbraceOTelInternal
        import EmbraceCommonInternal
        import EmbraceSemantics
    #endif

    protocol UIViewControllerHandlerDataSource: AnyObject {
        var serviceState: CaptureServiceState { get }
        var otel: EmbraceOpenTelemetry? { get }

        var instrumentVisibility: Bool { get }
        var instrumentFirstRender: Bool { get }

        func isViewControllerBlocked(_ vc: UIViewController) -> Bool
    }

    class UIViewControllerHandler {

        weak var dataSource: UIViewControllerHandlerDataSource?
        private let queue: DispatchableQueue

        struct ViewControllerHandlerMutableData {
            var parentSpans: [String: Span] = [:]
            var viewDidLoadSpans: [String: Span] = [:]
            var viewWillAppearSpans: [String: Span] = [:]
            var viewIsAppearingSpans: [String: Span] = [:]
            var viewDidAppearSpans: [String: Span] = [:]
            var visibilitySpans: [String: Span] = [:]
            var uiReadySpans: [String: Span] = [:]
            var alreadyFinishedUiReadyIds: Set<String> = []
        }
        private let data = EmbraceMutex(ViewControllerHandlerMutableData())

        init(queue: DispatchableQueue = .with(label: "com.embrace.UIViewControllerHandler", qos: .utility)) {
            self.queue = queue
            Embrace.notificationCenter.addObserver(
                self,
                selector: #selector(foregroundSessionDidEnd),
                name: .embraceForegroundSessionDidEnd,
                object: nil
            )
        }

        deinit {
            Embrace.notificationCenter.removeObserver(self)
        }

        func parentSpan(for vc: UIViewController) -> Span? {
            guard let id = vc.emb_instrumentation_state?.identifier else {
                return nil
            }

            return data.withLock { $0.parentSpans[id] }
        }

        @objc func foregroundSessionDidEnd(_ notification: Notification? = nil) {
            let now = notification?.object as? Date ?? Date()

            // end all parent spans and visibility spans if the app enters the background
            // also clear all the cached spans
            queue.async {
                for span in self.data.withLock({ $0.visibilitySpans.values }) {
                    span.end(time: now)
                }

                for id in self.data.withLock({ $0.parentSpans.keys }) {
                    self.forcefullyEndSpans(id: id, time: now)
                }

                self.data.withLock {
                    $0.parentSpans.removeAll()
                    $0.viewDidLoadSpans.removeAll()
                    $0.viewWillAppearSpans.removeAll()
                    $0.viewIsAppearingSpans.removeAll()
                    $0.viewDidAppearSpans.removeAll()
                    $0.visibilitySpans.removeAll()
                    $0.uiReadySpans.removeAll()
                    $0.alreadyFinishedUiReadyIds.removeAll()
                }

            }
        }

        func onViewDidLoadStart(_ vc: UIViewController, now: Date = Date()) {

            guard dataSource?.serviceState == .active,
                dataSource?.instrumentFirstRender == true,
                vc.emb_shouldCaptureView,
                dataSource?.isViewControllerBlocked(vc) == false,
                let otel = dataSource?.otel
            else {
                return
            }
            // We generate the id here, outside of the `queue`, to ensure we're doing it while the ViewController is still alive (renerding process).
            // There could be a race condition and it's possible that the controller was released or is in the process of deallocation,
            // which could cause a crash (as this feature relies on objc_setAssociatedObject).
            // This kind of operation should be done _for anything_ that accesses the UIViewController.
            let id = UUID().uuidString
            let state = ViewInstrumentationState()
            state.viewDidLoadSpanCreated = true
            state.identifier = id
            vc.emb_instrumentation_state = state

            let className = vc.className
            let viewName = vc.emb_viewName

            // check if with need to measure time-to-render or time-to-interactive
            let nameFormat =
                vc is InteractableViewController
                ? SpanSemantics.View.timeToInteractiveName : SpanSemantics.View.timeToFirstRenderName

            queue.async {
                // generate parent span

                let spanName = nameFormat.replacingOccurrences(of: "NAME", with: className)

                let parentSpan = self.createSpan(
                    with: otel,
                    viewName: viewName,
                    className: className,
                    name: spanName,
                    startTime: now
                )

                // generate view did load span
                let viewDidLoadSpan = self.createSpan(
                    with: otel,
                    viewName: viewName,
                    className: className,
                    name: SpanSemantics.View.viewDidLoadName,
                    startTime: now,
                    parent: parentSpan
                )

                self.data.withLock {
                    $0.parentSpans[id] = parentSpan
                    $0.viewDidLoadSpans[id] = viewDidLoadSpan
                }
            }
        }

        func onViewDidLoadEnd(_ vc: UIViewController, now: Date = Date()) {
            guard let id = vc.emb_instrumentation_state?.identifier else {
                return
            }
            queue.async {
                guard let span = self.data.withLock({ $0.viewDidLoadSpans.removeValue(forKey: id) }) else {
                    return
                }

                span.end(time: now)
            }
        }

        func onViewWillAppearStart(_ vc: UIViewController, now: Date = Date()) {
            guard let id = vc.emb_instrumentation_state?.identifier else {
                return
            }

            vc.emb_instrumentation_state?.viewWillAppearSpanCreated = true

            let className = vc.className
            let viewName = vc.emb_viewName

            queue.async {
                guard let otel = self.dataSource?.otel,
                    let parentSpan = self.data.withLock({ $0.parentSpans[id] })
                else {
                    return
                }

                // generate view will appear span
                let span = self.createSpan(
                    with: otel,
                    viewName: viewName,
                    className: className,
                    name: SpanSemantics.View.viewWillAppearName,
                    startTime: now,
                    parent: parentSpan
                )

                self.data.withLock {
                    $0.viewWillAppearSpans[id] = span
                }
            }
        }

        func onViewWillAppearEnd(_ vc: UIViewController, now: Date = Date()) {
            guard let id = vc.emb_instrumentation_state?.identifier else {
                return
            }
            queue.async {
                guard let span = self.data.withLock({ $0.viewWillAppearSpans.removeValue(forKey: id) }) else {
                    return
                }

                span.end(time: now)
            }
        }

        func onViewIsAppearingStart(_ vc: UIViewController, now: Date = Date()) {
            guard let id = vc.emb_instrumentation_state?.identifier else {
                return
            }

            vc.emb_instrumentation_state?.viewIsAppearingSpanCreated = true

            let className = vc.className
            let viewName = vc.emb_viewName

            queue.async {
                guard let otel = self.dataSource?.otel,
                    let parentSpan = self.data.withLock({ $0.parentSpans[id] })
                else {
                    return
                }

                // generate view is appearing span
                let span = self.createSpan(
                    with: otel,
                    viewName: viewName,
                    className: className,
                    name: SpanSemantics.View.viewIsAppearingName,
                    startTime: now,
                    parent: parentSpan
                )

                self.data.withLock {
                    $0.viewIsAppearingSpans[id] = span
                }
            }
        }

        func onViewIsAppearingEnd(_ vc: UIViewController, now: Date = Date()) {
            queue.async {
                guard let id = vc.emb_instrumentation_state?.identifier,
                    let span = self.data.withLock({ $0.viewIsAppearingSpans.removeValue(forKey: id) })
                else {
                    return
                }

                span.end(time: now)
            }
        }

        func onViewDidAppearStart(_ vc: UIViewController, now: Date = Date()) {
            guard let id = vc.emb_instrumentation_state?.identifier else {
                return
            }

            vc.emb_instrumentation_state?.viewDidAppearSpanCreated = true

            let className = vc.className
            let viewName = vc.emb_viewName

            queue.async {
                guard let otel = self.dataSource?.otel,
                    let parentSpan = self.data.withLock({ $0.parentSpans[id] })
                else {
                    return
                }

                // generate view did appear span
                let span = self.createSpan(
                    with: otel,
                    viewName: viewName,
                    className: className,
                    name: SpanSemantics.View.viewDidAppearName,
                    startTime: now,
                    parent: parentSpan
                )

                self.data.withLock {
                    $0.viewDidAppearSpans[id] = span
                }
            }
        }

        func onViewDidAppearEnd(_ vc: UIViewController, now: Date = Date()) {
            if self.dataSource?.instrumentVisibility == true {
                // Create id only if necessary. This could happen when `instrumentFirstRender` is `false`
                // in those cases, the `emb_identifier` will be `nil` and we need it to instrument visibility
                // (and in those cases that's enabled, also instrumenting the rendering process).
                // The reason why we're doing this outside of the utility `queue` can be found on `onViewDidLoadStart`.
                if vc.emb_instrumentation_state == nil {
                    vc.emb_instrumentation_state = ViewInstrumentationState(identifier: UUID().uuidString)
                }
            }

            guard let id = vc.emb_instrumentation_state?.identifier else {
                // This should never happen
                return
            }

            let className = vc.className
            let viewName = vc.emb_viewName

            queue.async {
                guard let otel = self.dataSource?.otel else {
                    return
                }

                // check if we need to create a visibility span
                if self.dataSource?.instrumentVisibility == true {
                    let span = self.createSpan(
                        with: otel,
                        viewName: viewName,
                        className: className,
                        name: SpanSemantics.View.screenName,
                        type: .view,
                        startTime: now
                    )
                    self.data.withLock { $0.visibilitySpans[id] = span }
                }

                if let span = self.data.withLock({ $0.viewDidAppearSpans.removeValue(forKey: id) }) {
                    span.end(time: now)
                }

                guard let parentSpan = self.data.withLock({ $0.parentSpans[id] }) else {
                    return
                }

                // end time to first render span
                if parentSpan.isTimeToFirstRender {
                    parentSpan.end(time: now)
                    self.clear(id: id)

                    // generate ui ready span
                } else {
                    let span = self.createSpan(
                        with: otel,
                        viewName: viewName,
                        className: className,
                        name: SpanSemantics.View.uiReadyName,
                        startTime: now,
                        parent: parentSpan
                    )

                    // if the view controller was already flagged as ready to interact
                    // we end the spans right away
                    if self.data.withLock({ $0.alreadyFinishedUiReadyIds.contains(id) }) {
                        span.end(time: now)
                        parentSpan.end(time: now)

                        self.clear(id: id)

                        // otherwise we save it to close it later
                    } else {
                        self.data.withLock { $0.uiReadySpans[id] = span }
                    }
                }
            }
        }

        func onViewDidDisappear(_ vc: UIViewController) {
            guard let id = vc.emb_instrumentation_state?.identifier else {
                return
            }

            queue.async {
                let now = Date()

                // end visibility span
                if let span = self.data.withLock({ $0.self.visibilitySpans[id] }) {
                    span.end(time: now)
                    self.data.withLock { $0.visibilitySpans[id] = nil }
                }

                // force end all spans
                self.forcefullyEndSpans(id: id, time: now)
            }
        }

        func onViewBecameInteractive(_ vc: UIViewController) {
            guard let id = vc.emb_instrumentation_state?.identifier else {
                return
            }

            queue.async {
                guard let parentSpan = self.data.withLock({ $0.parentSpans[id] }),
                    parentSpan.isTimeToInteractive
                else {
                    return
                }

                // if we have a ui ready span it means that viewDidAppear already happened
                // in this case we close the spans
                if let span = self.data.withLock({ $0.uiReadySpans[id] }) {
                    let now = Date()
                    span.end(time: now)
                    parentSpan.end(time: now)
                    self.clear(id: id)

                    // otherwise it means the view is still loading, in this case we flag
                    // the view controller so we can close the spans as soon as
                    // viewDidAppear ends
                } else {
                    self.data.withLock { $0.alreadyFinishedUiReadyIds.insert(id) }
                }
            }
        }

        private func forcefullyEndSpans(id: String, time: Date) {

            data.withLock {

                if let viewDidLoadSpan = $0.viewDidLoadSpans[id] {
                    viewDidLoadSpan.end(errorCode: .userAbandon, time: time)
                }

                if let viewWillAppearSpan = $0.viewWillAppearSpans[id] {
                    viewWillAppearSpan.end(errorCode: .userAbandon, time: time)
                }

                if let viewIsAppearingSpan = $0.viewIsAppearingSpans[id] {
                    viewIsAppearingSpan.end(errorCode: .userAbandon, time: time)
                }

                if let viewDidAppearSpan = $0.viewDidAppearSpans[id] {
                    viewDidAppearSpan.end(errorCode: .userAbandon, time: time)
                }

                if let uiReadySpan = $0.uiReadySpans[id] {
                    uiReadySpan.end(errorCode: .userAbandon, time: time)
                }

                if let parentSpan = $0.parentSpans[id] {
                    parentSpan.end(errorCode: .userAbandon, time: time)
                }

                // clear
                $0.parentSpans[id] = nil
                $0.viewDidLoadSpans[id] = nil
                $0.viewWillAppearSpans[id] = nil
                $0.viewIsAppearingSpans[id] = nil
                $0.viewDidAppearSpans[id] = nil
                $0.uiReadySpans[id] = nil
                $0.alreadyFinishedUiReadyIds.remove(id)

            }
        }

        private func createSpan(
            with otel: EmbraceOpenTelemetry,
            viewName: String,
            className: String,
            name: String,
            type: SpanType = .viewLoad,
            startTime: Date,
            parent: Span? = nil
        ) -> Span {
            let builder = otel.buildSpan(
                name: name,
                type: type,
                attributes: [
                    SpanSemantics.View.keyViewTitle: viewName,
                    SpanSemantics.View.keyViewName: className
                ],
                autoTerminationCode: nil
            )

            if let parent = parent {
                builder.setParent(parent)
            }

            builder.setStartTime(time: startTime)

            return builder.startSpan()
        }

        private func clear(id: String) {
            data.withLock {
                $0.parentSpans[id] = nil
                $0.viewDidLoadSpans[id] = nil
                $0.viewWillAppearSpans[id] = nil
                $0.viewIsAppearingSpans[id] = nil
                $0.viewDidAppearSpans[id] = nil
                $0.uiReadySpans[id] = nil
                $0.alreadyFinishedUiReadyIds.remove(id)
            }
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
