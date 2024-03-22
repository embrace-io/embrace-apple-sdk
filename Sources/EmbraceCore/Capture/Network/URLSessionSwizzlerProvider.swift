//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

protocol URLSessionSwizzlerProvider {
    func getAll(usingHandler handler: URLSessionTaskHandler) -> [any URLSessionSwizzler]
}

struct DefaultURLSessionSwizzlerProvider: URLSessionSwizzlerProvider {
    func getAll(usingHandler handler: URLSessionTaskHandler) -> [any URLSessionSwizzler] {
        let urlSessionLocalType: AnyClass = type(of: URLSession.shared)
        let swizzlingTypes: [any URLSessionSwizzler.Type] = [
            // Data Tasks
            DataTaskWithURLSwizzler.self,
            DataTaskWithURLRequestSwizzler.self,
            DataTaskWithURLAndCompletionSwizzler.self,
            DataTaskWithURLRequestAndCompletionSwizzler.self,

            // Upload Tasks
            UploadTaskWithRequestFromDataSwizzler.self,
            UploadTaskWithRequestFromDataWithCompletionSwizzler.self,
            UploadTaskWithRequestFromFileSwizzler.self,
            UploadTaskWithRequestFromFileWithCompletionSwizzler.self,

            // Download Tasks
            DownloadTaskWithURLRequestSwizzler.self,
            DownloadTaskWithURLRequestWithCompletionSwizzler.self,

            // Upload Streaming Tasks
            UploadTaskWithStreamedRequestSwizzler.self
        ]
        var swizzlers: [any URLSessionSwizzler] = []

        for swizzlingType in swizzlingTypes {
            swizzlers.append(swizzlingType.init(handler: handler, baseClass: URLSession.self))
            if !hasTheSameImplementation(for: swizzlingType.selector, lhs: urlSessionLocalType, rhs: URLSession.self) {
                swizzlers.append(swizzlingType.init(handler: handler, baseClass: urlSessionLocalType))
            }
        }

        swizzlers.append(URLSessionInitWithDelegateSwizzler(handler: handler))
        swizzlers.append(SessionTaskResumeSwizzler(handler: handler))

        return swizzlers
    }

    /// Compares two `AnyClass` (the old objc `Class`) to see if the implementation (pointer) for a selector is the same or not.
    ///
    /// This method is necessary because there're some classes where a class, and a subclass might implement methods
    /// in a different way. For example, `URLSession` implementation of some methods might differ from the implementation
    /// of some methods of `URLSession.shared` (aka. `__URLSessionLocal`). In those cases we have to know if the method
    /// implementation differs to be sure what are we going to swizzle.
    ///
    /// - Parameters:
    ///   - selector: The selector to compare the implementations for.
    ///   - lhs: The first class to compare.
    ///   - rhs: The second class to compare.
    /// - Returns: `true` if the implementations of the specified selector are the same in both classes; `false` otherwise.
    func hasTheSameImplementation(for selector: Selector, lhs: AnyClass, rhs: AnyClass) -> Bool {
        guard let leftImplementation = class_getMethodImplementation(lhs, selector),
              let rightImplementation = class_getMethodImplementation(rhs, selector) else {
            return false
        }

        return leftImplementation == rightImplementation
    }
}
