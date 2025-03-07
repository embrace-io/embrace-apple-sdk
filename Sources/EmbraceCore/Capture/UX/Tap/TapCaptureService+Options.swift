//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation
import UIKit

extension TapCaptureService {
    /// Defines when a tap event should be recorded.
    ///
    /// This allows configuring whether the tap is captured at the beginning (`.onStart`)
    /// or when the user lifts their finger (`.onEnd`), ensuring more control over what
    /// is considered a valid tap.
    @objc(EMBTapCaptureServiceTapPhase)
    public enum TapPhase: Int {
        /// Captures the tap when the user first touches the screen.
        case onStart

        /// Captures the tap only when the user lifts their finger.
        case onEnd

        /// Converts the `TapPhase` enum into its corresponding `UITouch.Phase` value.
        ///
        /// - Returns: the equivalent `UITouch.Phase`
        func asUITouchPhase() -> UITouch.Phase {
            switch self {
            case .onStart:
                return .began
            case .onEnd:
                return .ended
            }
        }
    }

    /// Class used to setup a TapCaptureService.
    @objc(EMBTapCaptureServiceOptions)
    public final class Options: NSObject {
        /// Defines a list of UIView types to be ignored by this service. Any taps done on views of these types will not be recorded.
        @objc public let ignoredViewTypes: [AnyClass]

        /// Defines wether the service should capture the coordinates of the taps.
        @objc public let captureTapCoordinates: Bool

        /// Delegate used to decide if each individual tap should be recorded or not.
        @objc public let delegate: TapCaptureServiceDelegate?

        /// Specifies when a tap should be recorded.
        @objc public let tapPhase: TapPhase

        @objc public init(
            ignoredViewTypes: [AnyClass] = [],
            captureTapCoordinates: Bool = true,
            tapPhase: TapPhase = .onStart,
            delegate: TapCaptureServiceDelegate? = nil
        ) {
            self.ignoredViewTypes = ignoredViewTypes
            self.captureTapCoordinates = captureTapCoordinates
            self.delegate = delegate
            self.tapPhase = tapPhase
        }

        @objc public convenience override init() {
            self.init(
                ignoredViewTypes: [],
                captureTapCoordinates: true,
                delegate: nil
            )
        }
    }
}
#endif
