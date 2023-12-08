//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

extension Embrace {

    @objc(EMBOptions)
    public final class Options: NSObject {
        @objc public let appId: String
        @objc public let appGroupId: String?
        @objc public let platform: Platform
        @objc public let endpoints: Embrace.Endpoints
        @objc public let services: [CaptureService]

        @objc public init(
            appId: String,
            appGroupId: String? = nil,
            platform: Platform = .iOS,
            endpoints: Embrace.Endpoints = .init(),
            captureServices: [CaptureService] = .automatic

        ) {
            self.appId = appId
            self.appGroupId = appGroupId
            self.platform = platform
            self.endpoints = endpoints
            self.services = captureServices
        }
    }
}

extension Embrace.Options: ExpressibleByStringLiteral {

    public convenience init(stringLiteral value: String) {
        self.init(appId: value)
    }

}

internal extension Embrace.Options {
    func validateAppId() throws {
        // this also covers if it's empty
        if self.appId.count != 5 {
            throw EmbraceSetupError.invalidAppId("App Id must be 5 characters in length")
        }
    }

    func validateGroupId() throws {
        if let groupId = self.appGroupId {
            if groupId.isEmpty {
                throw EmbraceSetupError.invalidAppGroupId("group id must not be empty if provided")
            }
        }
    }
}
