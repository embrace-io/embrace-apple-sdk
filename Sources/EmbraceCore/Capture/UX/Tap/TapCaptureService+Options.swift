//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation

extension TapCaptureService {
    /// Class used to setup a TapCaptureService.
    @objc(EMBTapCaptureServiceOptions)
    public final class Options: NSObject {
        /// Defines a list of UIView types to be ignored by this service. Any taps done on views of these types will not be recorded.
        @objc public let ignoredViewTypes: [AnyClass]

        /// Defines wether the service should capture the coordinates of the taps.
        @objc public let captureTapCoordinates: Bool

        /// Delegate used to decide if each indivudual tap should be recorded or not.
        @objc public let delegate: TapCaptureServiceDelegate?

        @objc public init(
            ignoredViewTypes: [AnyClass] = [],
            captureTapCoordinates: Bool = true,
            delegate: TapCaptureServiceDelegate? = nil
        ) {
            self.ignoredViewTypes = ignoredViewTypes
            self.captureTapCoordinates = captureTapCoordinates
            self.delegate = delegate
        }

        @objc public convenience override init() {
            self.init(ignoredViewTypes: [], captureTapCoordinates: true, delegate: nil)
        }
    }
}
#endif
