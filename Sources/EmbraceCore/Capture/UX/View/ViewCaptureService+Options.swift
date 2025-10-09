//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    extension ViewCaptureService {
        /// Class used to setup a `ViewCaptureService`.
        public struct Options {
            /// When enabled, the capture service will generate spans that measure the visible period of a `UIViewController`.
            /// The spans start  on `viewDidAppear` and end on `viewDidDisappear`.
            public let instrumentVisibility: Bool

            /// When enabled, the capture service will generate spans that measure the loading process of a `UIViewController`
            /// until it renders for the first time.
            /// The parent span (`time-to-first-render`) starts on `viewDidLoad` and ends on `viewDidAppear`.
            /// This span will contain contain child spans measuring each step in the process (`viewDidLoad`, `viewWillAppear` and `viewDidDisappear`).
            /// If the `UIViewController` follows the `InstrumentableViewController` protocol, custom child
            /// spans can be added to the parent span as well.
            ///
            /// If the `UIViewController` follows the `InteractableViewController` protocol, the parent span will end
            /// when the view is ready to be interacted instead (`time-to-interactive`).
            /// The implementers will need to call `setInteractionReady()` on the `UIViewController` to mark the end time.
            /// If the `UIViewController` disappears before the interaction is set as ready, the span status will be set to `error`
            /// with the `userAbandon` error code.
            public var instrumentFirstRender: Bool

            /// Any `UIViewController` contained in this block list will be ignored by the capture service.
            /// Use the `blockHostingControllers` paramenter to determine if `UIHostingControllers` and their child controllers should be captured.
            public var viewControllerBlockList: ViewControllerBlockList

            public init(
                instrumentVisibility: Bool = true,
                instrumentFirstRender: Bool = true,
                viewControllerBlockList: ViewControllerBlockList = ViewControllerBlockList()
            ) {
                self.instrumentVisibility = instrumentVisibility
                self.instrumentFirstRender = instrumentFirstRender
                self.viewControllerBlockList = viewControllerBlockList
            }
        }
    }
#endif
