//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceCore
@testable @_implementationOnly import EmbraceObjCUtilsInternal

class MockURLSessionSwizzler: URLSessionSwizzler {
    // Random types and selector. This class shouldn't actually swizzle anything as methods are overriden.
    typealias ImplementationType = URLSession
    typealias BlockImplementationType = URLSession
    static var selector: Selector = #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask)
    var baseClass: AnyClass = URLSession.self

    required init(handler: URLSessionTaskHandler, baseClass: AnyClass) {}

    convenience init() {
        self.init(handler: MockURLSessionTaskHandler(), baseClass: Self.self)
    }

    var didInstall = false
    var installInvokationCount: Int = 0
    func install() throws {
        didInstall = true
        installInvokationCount += 1
    }

    var didSwizzleInstanceMethod = false
    func swizzleInstanceMethod(_ block: (NSString) -> NSString) throws {
        didSwizzleInstanceMethod = true
    }

    var didSwizzleClassMethod = false
    func swizzleClassMethod(_ block: (NSString) -> NSString) throws {
        didSwizzleClassMethod = true
    }
}

class ThrowingURLSessionSwizzler: MockURLSessionSwizzler {
    override func install() throws {
        didInstall = true
        throw NSError(domain: UUID().uuidString, code: Int.random(in: 0..<Int.max))
    }
}
