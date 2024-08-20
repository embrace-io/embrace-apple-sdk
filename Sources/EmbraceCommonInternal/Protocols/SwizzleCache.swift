//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if DEBUG
/// This class acts as a container for all the original implementations
/// of the swizzled methods around the SDK.
///
/// Important: This class is meant to be used for testing only
public class SwizzleCache {
    /// This structure is a complementary class used to uniquely identify and store the original method
    /// implementations before method swizzling is applied. It facilitates the process of unswizzling
    /// the original method implementations when needed.
    struct OriginalMethod: Hashable {
        let method: Method
        let baseClass: AnyClass
        let swizzlerClass: String

        fileprivate init(
            method: Method,
            baseClass: AnyClass,
            swizzlerClass: String
        ) {
            self.method = method
            self.baseClass = baseClass
            self.swizzlerClass = swizzlerClass
        }

        static func == (lhs: OriginalMethod, rhs: OriginalMethod) -> Bool {
            let methodParity = lhs.method == rhs.method
            let classParity = NSStringFromClass(lhs.baseClass) == NSStringFromClass(rhs.baseClass)
            let swizzlerClassParity = lhs.swizzlerClass == rhs.swizzlerClass
            return methodParity && classParity && swizzlerClassParity
        }

        func hash(into hasher: inout Hasher) {
            let methodName = NSStringFromSelector(method_getName(method))
            let className = NSStringFromClass(baseClass)
            let identifier = "\(swizzlerClass)-\(className)-\(methodName)"
            hasher.combine(identifier)
        }
    }

    public static let shared: SwizzleCache = {
        return SwizzleCache()
    }()

    private let lock = NSLock()
    private var originalImplementations: [OriginalMethod: IMP] = [:]

    private init() { }

    func addMethodImplementation(
        _ imp: IMP,
        forMethod method: Method,
        inClass baseClass: AnyClass,
        swizzler: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        originalImplementations[
            OriginalMethod(
                method: method,
                baseClass: baseClass,
                swizzlerClass: swizzler
            )
        ] = imp
    }

    public func getOriginalMethodImplementation(
        forMethod method: Method,
        inClass baseClass: AnyClass,
        swizzler: String
    ) -> IMP? {
        lock.lock()
        defer { lock.unlock() }
        return originalImplementations[
            OriginalMethod(
                method: method,
                baseClass: baseClass,
                swizzlerClass: swizzler
            )
        ]
    }

    public func removeOriginalMethodImplementation(
        forMethod method: Method,
        inClass baseClass: AnyClass,
        swizzler: String
    ) {
        originalImplementations.removeValue(forKey: OriginalMethod(
            method: method,
            baseClass: baseClass,
            swizzlerClass: swizzler
        ))
    }
}
#endif
