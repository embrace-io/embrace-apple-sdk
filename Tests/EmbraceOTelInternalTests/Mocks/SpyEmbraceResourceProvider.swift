//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceOTelInternal

class SpyEmbraceResourceProvider: EmbraceResourceProvider {
    var stubbedGetResources: [EmbraceResource] = []
    func getResources() -> [EmbraceResource] {
        stubbedGetResources
    }
}
