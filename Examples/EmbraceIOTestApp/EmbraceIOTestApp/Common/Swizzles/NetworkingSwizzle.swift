//
//  NetworkingSwizzle.swift
//  EmbraceIOTestApp
//
//

import Foundation
import EmbraceCommonInternal
import EmbraceCore


class NetworkingSwizzle: NSObject {
    private typealias URLSessionCompletion = (Data?, URLResponse?, Error?) -> Void
    private typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, URLSessionCompletion?) -> URLSessionDataTask
    private typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, URLSessionCompletion?) -> URLSessionDataTask

    static private var initialized = false

    override init() {
        super.init()
        do { try setup() } catch {}
    }

    private func setup() throws {
        guard !NetworkingSwizzle.initialized else { return }

        NetworkingSwizzle.initialized = true

        let selector: Selector = #selector(
            URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping URLSessionCompletion) -> URLSessionDataTask
        )

        guard let method = class_getInstanceMethod(URLSession.self, selector) else { return }
        let originalImp = method_getImplementation(method)

        let newImplementationBlock: BlockImplementationType = { urlSession, urlRequest, completion -> URLSessionDataTask in
            let originalMethod = unsafeBitCast(originalImp, to: ImplementationType.self)
            if let data = urlRequest.httpBody {
                if let uncompressed = try? data.gunzipped() {
                    if let json = try? JSONSerialization.jsonObject(with: uncompressed) {

                    }
                }
            }
            let task = originalMethod(urlSession, selector, urlRequest, completion)
            return task
        }
        let newImplementation = imp_implementationWithBlock(newImplementationBlock)
        method_setImplementation(method, newImplementation)
    }
}
