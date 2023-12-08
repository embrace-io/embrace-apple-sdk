//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel
import EmbraceStorage

extension EmbraceSpanProcessor where Self == SingleSpanProcessor {
    static func with(storage: EmbraceStorage) -> SingleSpanProcessor {
        let exporter = StorageSpanExporter(options: .init(storage: storage))
        return SingleSpanProcessor(spanExporter: exporter)
    }
}
