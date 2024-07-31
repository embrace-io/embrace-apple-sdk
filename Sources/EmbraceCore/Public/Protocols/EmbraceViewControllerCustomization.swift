//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit)

import UIKit

/// Implement this protocol on your ViewControllers to customize certain aspects of how Embrace logs you ViewControllers.
public protocol EmbraceViewControllerCustomization {

    /// Optional.
    /// Embrace uses the `title` property of your ViewController by default.
    /// Implement this property in your ViewController if you'd like Embrace to log the ViewController under a different name without modifying the `title` property.
    var nameForViewControllerInEmbrace: String? { get }

    /// Optional.
    /// By default, Embrace will capture a Span to represent every view controller that appears
    /// Implement this var and set it to return `false` if you'd like Embrace to skip logging this view.
    var shouldCaptureViewInEmbrace: Bool { get }
}

/// Default implementation for `EmbraceViewControllerCustomization` methods that are intended to be optional.
public extension EmbraceViewControllerCustomization where Self: UIViewController {
    var nameForViewControllerInEmbrace: String? { self.title }
    var shouldCaptureViewInEmbrace: Bool { true }
}

#endif
