//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceOTel

class DummyEmbraceResourceProvider: EmbraceResourceProvider {
    func getResources() -> [EmbraceResource] { [] }
}
