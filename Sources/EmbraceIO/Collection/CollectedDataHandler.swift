//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

protocol CollectedResourceHandlerType {
    func addResource(key: String, value: String) throws
    func addResource(key: String, value: Int) throws
    func addResource(key: String, value: Double) throws
}

class CollectedResourceHandler: NSObject, CollectedResourceHandlerType {
    func addResource(key: String, value: String) throws {
        try Embrace.client?.addResource(key: key, value: value)
    }

    func addResource(key: String, value: Int) throws {
        try Embrace.client?.addResource(key: key, value: value)
    }

    func addResource(key: String, value: Double) throws {
        try Embrace.client?.addResource(key: key, value: value)
    }
}
