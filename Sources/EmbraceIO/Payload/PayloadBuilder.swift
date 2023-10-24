//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage

class PayloadBuilder {
    let options: EmbraceOptions
    let serializer: PayloadSerializerType

    init(with options: EmbraceOptions, serializer: PayloadSerializerType = PayloadSerializer()) {
        self.options = options
        self.serializer = serializer
    }

    func prepareSessionPayload(from sessionRecord: SessionRecord) -> Data? {
        let sessionPayload = SessionPayload(with: sessionRecord)
        return serializer.serializeAndGZipJson(sessionPayload).data
    }
}
