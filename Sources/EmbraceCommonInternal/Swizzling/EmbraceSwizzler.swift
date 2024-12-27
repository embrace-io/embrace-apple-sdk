//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
import ObjectiveC.runtime

public class EmbraceSwizzler {
    public init() {}
    
    /// Swizzles a specific instance method of a given class.
    ///
    /// This method allows you to replace the implementation of an instance method in the specified class (`type`)
    /// with a custom implementation provided as a block. Only the implementation of the specified class is swizzled,
    /// and parent class methods with the same selector are not affected.
    ///
    /// - Parameters:
    ///   - type: The class in which the method resides. The method to be swizzled **must belong to this class specifically**.
    ///   - selector: The selector for the instance method to be swizzled.
    ///   - implementationType: The expected function signature of the original method (use `@convention(c)`)
    ///   - blockImplementationType: The expected function signature of the new implementation block (use `@convention(block)`)
    ///   - block: A closure that accepts the original implementation as input (`implementationType.Type`) and provides the
    ///   new implementation (`blockImplementationType.Type`)
    ///
    /// - Important: This method only operates on methods explicitly declared in the specified class. If the method is inherited from a parent class, **it wont be swizzled**.
    public func swizzleDeclaredInstanceMethod<T, F>(
        in type: AnyClass,
        selector: Selector,
        implementationType: T.Type,
        blockImplementationType: F.Type,
        _ block: @escaping (T) -> F
    ) throws {

        // Find the method in the specified class
        var methodToSwizzle: Method?
        var methodCount: UInt32 = 0

        // We use `class_copyMethodList` and search for the method instead of using `class_getInstanceMethod`
        // because we don't want to modify the `superclass` implementation.
        let methods = class_copyMethodList(type, &methodCount)
        if let methods = methods {
            for index in 0..<Int(methodCount) {
                let method = methods[index]
                if sel_isEqual(method_getName(method), selector) {
                    methodToSwizzle = method
                    break
                }
            }

        }

        free(methods)

        // If the method is not found, we exit early. This is not a real problem, that's why we don't throw as in `Swizzlable`
        guard let method = methodToSwizzle else {
            return
        }

        // Retrieve the original implementation of the method
        let originalImplementation = method_getImplementation(method)
        saveInCache(originalImplementation: originalImplementation, forMethod: method, associatedToClass: type)

        // Create a block implementation by invoking the provided closure, passing the original implementation as input.
        let originalTypifiedImplementation = unsafeBitCast(originalImplementation, to: implementationType)
        let newImplementationBlock: F = block(originalTypifiedImplementation)
        let newImplementation = imp_implementationWithBlock(newImplementationBlock)

        // Do the actual IMP replacement 
        method_setImplementation(method, newImplementation)
    }

    private func saveInCache(originalImplementation: IMP, forMethod method: Method, associatedToClass: AnyClass) {
        #if DEBUG
        let swizzlerClassName = String(describing: type(of: self))
        SwizzleCache.shared.addMethodImplementation(originalImplementation,
                                                    forMethod: method,
                                                    inClass: associatedToClass,
                                                    swizzler: swizzlerClassName)
        #endif
    }
}
