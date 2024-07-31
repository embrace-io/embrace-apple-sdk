//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionDelegateProxy: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let selector = #selector(
            URLSessionDownloadDelegate.urlSession(_:downloadTask:didFinishDownloadingTo:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionDownloadDelegate) in
            delegate.urlSession(session,
                                 downloadTask: downloadTask,
                                 didFinishDownloadingTo: location)
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {

        let selector = #selector(
            URLSessionDownloadDelegate
                .urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionDownloadDelegate) in
            delegate.urlSession?(session,
                                downloadTask: downloadTask,
                                didWriteData: bytesWritten,
                                totalBytesWritten: totalBytesWritten,
                                totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64) {
        let selector = #selector(
            URLSessionDownloadDelegate.urlSession(_:downloadTask:didResumeAtOffset:expectedTotalBytes:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionDownloadDelegate) in
            delegate.urlSession?(session,
                                 downloadTask: downloadTask,
                                 didResumeAtOffset: fileOffset,
                                 expectedTotalBytes: expectedTotalBytes)
        }
    }
}
