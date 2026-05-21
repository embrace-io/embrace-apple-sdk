//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if DEBUG
    /// This class acts as a container for storing original implementations of methods that have been swizzled by the SDK.
    ///
    /// Important: This class is intended for testing purposes only.
    public class SwizzleCache {
        /// This class uniquely identifies and stores original method implementations before swizzling.
        /// It is used to make easier the unswizzling process by identifying the method implementation based on the Method,
        /// the swizzled class, and the class performing the swizzle operation.
        struct OriginalMethod: Hashable {
            /// The method whose original implementation was overridden.
            let method: Method

            /// The class where the method resides that was swizzled (e.g., `UIWindow`, `NSURLSession`).
            let baseClass: AnyClass

            /// A String describing the type of the class that performs the swizzling.
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

        /// Signal raised when `addMethodImplementation` sees a duplicate install for the same
        /// `(method, baseClass, swizzler)` key. Default fires `assertionFailure`. Tests that
        /// intentionally exercise the duplicate-install contract override this (e.g. to record
        /// the call) and are responsible for any logging they need.
        ///
        /// Whether or not this signal traps, the duplicate write is always skipped — the cached
        /// "true original" stays intact so a subsequent unswizzle still restores it correctly.
        public static var onDuplicateInstall: (String) -> Void = { message in
            assertionFailure(message)
        }

        private let lock = NSLock()
        private var originalImplementations: [OriginalMethod: IMP] = [:]

        private init() {}

        func addMethodImplementation(
            _ imp: IMP,
            forMethod method: Method,
            inClass baseClass: AnyClass,
            swizzler: String
        ) {
            lock.lock()
            defer { lock.unlock() }
            let key = OriginalMethod(
                method: method,
                baseClass: baseClass,
                swizzlerClass: swizzler
            )
            if originalImplementations[key] != nil {
                let className = NSStringFromClass(baseClass)
                let selectorName = NSStringFromSelector(method_getName(method))
                Self.onDuplicateInstall(
                    "SwizzleCache: \(swizzler) installed twice on \(className).\(selectorName) without an unswizzle in between."
                )
                return
            }
            originalImplementations[key] = imp
        }

        /// Whether the cache currently holds any swizzled-method entries. Intended for tests.
        public var isEmpty: Bool {
            lock.lock()
            defer { lock.unlock() }
            return originalImplementations.isEmpty
        }

        /// Snapshot of cache contents as human-readable strings, sorted for stable output.
        /// Intended for tests.
        public var residueDescription: [String] {
            lock.lock()
            defer { lock.unlock() }
            return originalImplementations.keys.map { key in
                "\(key.swizzlerClass) on \(NSStringFromClass(key.baseClass)).\(NSStringFromSelector(method_getName(key.method)))"
            }.sorted()
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
            originalImplementations.removeValue(
                forKey: OriginalMethod(
                    method: method,
                    baseClass: baseClass,
                    swizzlerClass: swizzler
                ))
        }
    }
#endif
