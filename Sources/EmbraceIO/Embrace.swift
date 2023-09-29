//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel
import EmbraceStorage

@objc public class Embrace: NSObject {

    @objc public private(set) static var client: Embrace?
    @objc public private(set) var options: EmbraceOptions

    private override init() {
        fatalError("Use init(options:) instead")
    }

    private init(options: EmbraceOptions) {
        self.options = options
        super.init()

        let storage: EmbraceStorage? = nil // TO DO: Need to get correct storage
        EmbraceOTel.setup(storage: storage!)
    }

    @objc public class func setup(options: EmbraceOptions) {
        if client != nil {
            print("Embrace was already initialized!")
            return
        }

        client = Embrace(options: options)
    }

    @objc public func start() {

    }

}
