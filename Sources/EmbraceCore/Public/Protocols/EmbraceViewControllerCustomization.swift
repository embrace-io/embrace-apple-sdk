//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit)

import UIKit

/// Implement this protocol on your ViewControllers to customize certain aspects of how Embrace logs you ViewControllers.
public protocol EmbraceViewControllerCustomization {

    /// Embrace uses the `title` property of your ViewController by default.
    /// Implement this method if you'd like Embrace to log the ViewController under a different name without modifying the `title` property.
    func nameForViewControllerInEmbrace() -> String?
}

/// Default implementation for `EmbraceViewControllerCustomization` methods that are intended to be optional.
public extension EmbraceViewControllerCustomization where Self: UIViewController {
    func nameForViewControllerInEmbrace() -> String? { self.title }
}

#endif
