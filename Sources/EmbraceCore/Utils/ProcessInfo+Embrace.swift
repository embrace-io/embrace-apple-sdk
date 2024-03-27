//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension ProcessInfo {
    var isSwiftUIPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
