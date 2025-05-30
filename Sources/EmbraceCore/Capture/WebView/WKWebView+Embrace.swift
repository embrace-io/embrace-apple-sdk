//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
#if !EMBRACE_COCOAPOD_BUILDING_SDK
@_implementationOnly import EmbraceObjCUtilsInternal
#endif
import Foundation
import WebKit

extension WKWebView {
    private struct AssociatedKeys {
        static var embraceProxy: Int = 0
    }

    var emb_proxy: EMBWKNavigationDelegateProxy? {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.embraceProxy)
                as? EMBWKNavigationDelegateProxy {
                return value as EMBWKNavigationDelegateProxy
            }

            return nil
        }

        set {
            objc_setAssociatedObject(self,
                                     &AssociatedKeys.embraceProxy,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

#endif
