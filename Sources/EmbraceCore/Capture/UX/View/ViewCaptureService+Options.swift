//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

extension ViewCaptureService {
    enum InstrumentFirstRenderMode {
        case automatic
        case manual(viewControllers: [UIViewController.Type])
        case off

        func isOn() -> Bool {
            if case .off = self {
                return false
            }
            return true
        }
    }

    /// Class used to setup a `ViewCaptureService`.
    @objc(EMBViewCaptureServiceOptions)
    public final class Options: NSObject {
        /// When enabled, the capture service will generate spans that measure the visible period of a `UIViewController`.
        /// The spans start  on `viewDidAppear` and end on `viewDidDisappear`.
        @objc public let instrumentVisibility: Bool

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
        @objc public var instrumentFirstRender: Bool {
            instrumentFirstRenderMode.isOn()
        }

        let instrumentFirstRenderMode: InstrumentFirstRenderMode

        @objc public convenience init(instrumentVisibility: Bool, instrumentFirstRender: Bool) {
            self.init(
                instrumentVisibility: instrumentVisibility,
                firstRenderInstrumentationMode: instrumentFirstRender ? .automatic : .off
            )
        }

        private init(instrumentVisibility: Bool, firstRenderInstrumentationMode: InstrumentFirstRenderMode) {
            self.instrumentVisibility = instrumentVisibility
            self.instrumentFirstRenderMode = firstRenderInstrumentationMode
        }

        @objc public convenience override init() {
            self.init(instrumentVisibility: true, instrumentFirstRender: true)
        }
    }
}
#endif
