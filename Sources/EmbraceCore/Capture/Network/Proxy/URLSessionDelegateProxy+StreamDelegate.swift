//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionDelegateProxy: URLSessionStreamDelegate {
    func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
        let selector = #selector(
            URLSessionStreamDelegate.urlSession(_:readClosedFor:)
        )
        if originalDelegateResponds(to: selector),
           let task = originalDelegate as? URLSessionStreamDelegate {
            task.urlSession?(session, readClosedFor: streamTask)
        }
    }

    func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
        let selector = #selector(
            URLSessionStreamDelegate.urlSession(_:writeClosedFor:)
        )
        if originalDelegateResponds(to: selector),
           let task = originalDelegate as? URLSessionStreamDelegate {
            task.urlSession?(session, writeClosedFor: streamTask)
        }
    }

    func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
        let selector = #selector(
            URLSessionStreamDelegate.urlSession(_:betterRouteDiscoveredFor:)
        )
        if originalDelegateResponds(to: selector),
           let task = originalDelegate as? URLSessionStreamDelegate {
            task.urlSession?(session, betterRouteDiscoveredFor: streamTask)
        }
    }

    func urlSession(_ session: URLSession,
                    streamTask: URLSessionStreamTask,
                    didBecome inputStream: InputStream,
                    outputStream: OutputStream) {
        let selector = #selector(
            URLSessionStreamDelegate.urlSession(_:streamTask:didBecome:outputStream:)
        )
        if originalDelegateResponds(to: selector),
           let task = originalDelegate as? URLSessionStreamDelegate {
            task.urlSession?(session,
                             streamTask: streamTask,
                             didBecome: inputStream,
                             outputStream: outputStream)
        }
    }
}
