//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public class EmbraceEndpoints: NSObject {

    @objc public let dataBaseUrlPath: String
    @objc public let dataDevBaseUrlPath: String
    @objc public let configBaseUrlPath: String
    @objc public let imagesBaseUrlPath: String

    override convenience init() {
        self.init(dataBaseUrlPath: nil, dataDevBaseUrlPath: nil, configBaseUrlPath: nil, imagesBaseUrlPath: nil)
    }

    @objc public init(dataBaseUrlPath: String?, dataDevBaseUrlPath: String?, configBaseUrlPath: String?, imagesBaseUrlPath: String?) {
        self.dataBaseUrlPath = dataBaseUrlPath ?? "data.emb-api.com"
        self.dataDevBaseUrlPath = dataDevBaseUrlPath ?? "data-dev.emb-api.com"
        self.configBaseUrlPath = configBaseUrlPath ?? "config.emb-api.com"
        self.imagesBaseUrlPath = imagesBaseUrlPath ?? "images.emb-api.com"
    }
}
