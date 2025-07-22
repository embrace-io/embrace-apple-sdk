//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// The `Swizzlable` protocol defines a set of methods and properties for enabling method swizzling in classes.
public protocol Swizzlable {

    /// The associated type representing the original method implementation.
    associatedtype ImplementationType

    /// The associated type representing the new method implementation as a block.
    associatedtype BlockImplementationType

    /// The selector representing the method to be swizzled.
    static var selector: Selector { get }

    /// The class on which method swizzling will be performed.
    var baseClass: AnyClass { get }

    /// Should be called when the swizzling should be executed.
    func install() throws

    /// Swizzles an instance method of the base class with a new implementation provided as a block.
    ///
    /// - Parameter block: A block representing the new implementation.
    /// - Throws: An error if the method specified by the selector is not found.
    func swizzleInstanceMethod(_ block: (ImplementationType) -> BlockImplementationType) throws

    /// Swizzles a class method of the base class with a new implementation provided as a block.
    ///
    /// - Parameter block: A block representing the new implementation.
    /// - Throws: An error if the method specified by the selector is not found.
    func swizzleClassMethod(_ block: (ImplementationType) -> BlockImplementationType) throws
}

extension Swizzlable {
    public func swizzleInstanceMethod(_ block: (ImplementationType) -> BlockImplementationType) throws {
        guard let method = class_getInstanceMethod(baseClass, Self.selector) else {
            throw EmbraceSwizzableError.methodNotFound(selectorName: "\(Self.selector)", className: "\(type(of: self))")
        }
        swizzle(method: method, withBlock: block)
    }

    public func swizzleClassMethod(_ block: (ImplementationType) -> BlockImplementationType) throws {
        guard let method = class_getClassMethod(baseClass, Self.selector) else {
            throw EmbraceSwizzableError.methodNotFound(selectorName: "\(Self.selector)", className: "\(type(of: self))")
        }
        swizzle(method: method, withBlock: block)
    }

    private func swizzle(method: Method, withBlock block: (ImplementationType) -> BlockImplementationType) {
        let originalImplementation = method_getImplementation(method)
        saveInCache(originalImplementation: originalImplementation, forMethod: method)
        let originalTypifiedImplementation = unsafeBitCast(
            originalImplementation,
            to: ImplementationType.self)
        let newImplementationBlock: BlockImplementationType = block(originalTypifiedImplementation)
        let newImplementation = imp_implementationWithBlock(newImplementationBlock)
        method_setImplementation(method, newImplementation)
    }

    private func saveInCache(originalImplementation: IMP, forMethod method: Method) {
        #if DEBUG
            let swizzlerClassName = String(describing: type(of: self))
            SwizzleCache.shared.addMethodImplementation(
                originalImplementation,
                forMethod: method,
                inClass: baseClass,
                swizzler: swizzlerClassName)
        #endif
    }
}
