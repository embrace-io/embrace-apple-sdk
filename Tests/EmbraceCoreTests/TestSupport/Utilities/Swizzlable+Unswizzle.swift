//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceCore
import Foundation

extension Swizzlable {
    public func unswizzleInstanceMethod() throws {
        guard let method = class_getInstanceMethod(baseClass, Self.selector) else {
            throw UnswizzleError.noMethodForSelector(value: Self.selector, class: baseClass)
        }
        try unswizzle(method: method)
    }

    public func unswizzleClassMethod() throws {
        guard let method = class_getClassMethod(baseClass, Self.selector) else {
            throw UnswizzleError.noMethodForSelector(value: Self.selector, class: baseClass)
        }
        try unswizzle(method: method)
    }

    private func unswizzle(method: Method) throws {
        let swizzlerClassName = String(describing: type(of: self))
        guard
            let originalImplementation = SwizzleCache.shared.getOriginalMethodImplementation(
                forMethod: method,
                inClass: baseClass,
                swizzler: swizzlerClassName
            )
        else {
            throw UnswizzleError.implementationInCacheNotFound(method: method)
        }
        method_setImplementation(method, originalImplementation)
        SwizzleCache.shared.removeOriginalMethodImplementation(
            forMethod: method,
            inClass: baseClass,
            swizzler: swizzlerClassName
        )
    }
}

enum UnswizzleError: LocalizedError {
    case noMethodForSelector(value: Selector, class: AnyClass)
    case implementationInCacheNotFound(method: Method)

    var errorDescription: String? {
        switch self {
        case .noMethodForSelector(let value, let baseClass):
            return "No method for selector \(value) in class \(type(of: baseClass))"
        case .implementationInCacheNotFound(let method):
            return "No original implmentation of method \(method_getName(method)) was found"
        }
    }
}
