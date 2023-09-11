//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public class Embrace: NSObject {

    private override init() {
        super.init()
    }

    @objc public private(set) static var client: Embrace?
    @objc public private(set) var options: EmbraceOptions!

    @objc public class func setup(options: EmbraceOptions) {
        if client != nil {
            print("Embrace was already initialized!")
            return
        }

        client = Embrace()
        client?.options = options
    }

    @objc public func start() {

    }
}
