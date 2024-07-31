//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionDelegateProxy: URLSessionStreamDelegate {
    func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
        let selector = #selector(
            URLSessionStreamDelegate.urlSession(_:readClosedFor:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionStreamDelegate) in
            delegate.urlSession?(session, readClosedFor: streamTask)
        }
    }

    func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
        let selector = #selector(
            URLSessionStreamDelegate.urlSession(_:writeClosedFor:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionStreamDelegate) in
            delegate.urlSession?(session, writeClosedFor: streamTask)
        }
    }

    func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
        let selector = #selector(
            URLSessionStreamDelegate.urlSession(_:betterRouteDiscoveredFor:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionStreamDelegate) in
            delegate.urlSession?(session, betterRouteDiscoveredFor: streamTask)
        }
    }

    func urlSession(_ session: URLSession,
                    streamTask: URLSessionStreamTask,
                    didBecome inputStream: InputStream,
                    outputStream: OutputStream) {
        let selector = #selector(
            URLSessionStreamDelegate.urlSession(_:streamTask:didBecome:outputStream:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionStreamDelegate) in
            delegate.urlSession?(session,
                                 streamTask: streamTask,
                                 didBecome: inputStream,
                                 outputStream: outputStream)
        }
    }
}
