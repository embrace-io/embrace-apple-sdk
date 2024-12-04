//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
import Foundation
import WebKit

extension WKWebView {
    private struct AssociatedKeys {
        static var embraceProxy: Int = 0
    }

    var emb_proxy: WKNavigationDelegateProxy? {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.embraceProxy) as? WKNavigationDelegateProxy {
                return value as WKNavigationDelegateProxy
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
