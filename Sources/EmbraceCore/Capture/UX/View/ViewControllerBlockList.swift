//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import UIKit
    import SwiftUI

    /// Class used as a block list for the  `ViewCaptureService`.
    /// Can be configured with a list of types and names to select `UIViewControllers` to be ignored by the capture service.
    /// Additionally, `UIHostingControllers` and their child controllers can be ignored.
    @objc(EMBViewControllerBlockList)
    public class ViewControllerBlockList: NSObject {
        public let types: [AnyClass]
        public let names: [String]
        public let blockHostingControllers: Bool

        @objc public init(types: [AnyClass] = [], names: [String] = [], blockHostingControllers: Bool = true) {
            self.types = types
            self.names = names.map { $0.uppercased() }
            self.blockHostingControllers = blockHostingControllers
        }

        @MainActor
        func isBlocked(viewController: UIViewController) -> Bool {
            if blockHostingControllers && isHostingController(viewController) {
                return true
            }

            if contains(viewController) {
                return true
            }

            return false
        }

        @MainActor
        private func isHostingController(_ vc: UIViewController?) -> Bool {
            guard let vc else {
                return false
            }

            if vc is EmbraceIdentifiableHostingController {
                return true
            }

            return isHostingController(vc.parent)
        }

        private func contains(_ vc: UIViewController) -> Bool {
            return types.contains { vc.isKind(of: $0) } || names.contains { name(for: vc).contains($0) }
        }

        private func name(for vc: UIViewController) -> String {
            NSStringFromClass(type(of: vc)).uppercased()
        }
    }

    /// This protocol is solely used to identify `UIHostingControllers` and subclasses of it
    protocol EmbraceIdentifiableHostingController: AnyObject {}
    extension UIHostingController: EmbraceIdentifiableHostingController {}

#endif
