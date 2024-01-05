//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public protocol CaptureService {
    func start()
    func stop()
}

@objc public protocol InstalledCaptureService: CaptureService {
    func install(context: CaptureServiceContext)
    func uninstall()
}
