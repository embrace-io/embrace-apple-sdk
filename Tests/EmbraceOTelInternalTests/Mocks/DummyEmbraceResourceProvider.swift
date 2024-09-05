//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceOTelInternal

class DummyEmbraceResourceProvider: EmbraceResourceProvider {
    func getResource() -> Resource { Resource() }
}
