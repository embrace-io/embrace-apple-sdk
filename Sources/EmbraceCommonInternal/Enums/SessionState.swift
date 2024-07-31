//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum SessionState: String {
    case foreground
    case background
}

#if canImport(UIKit) && !os(watchOS)
import UIKit

public extension SessionState {
    init?(appState: UIApplication.State) {
        if appState == .background {
            self = .background
        } else {
            self = .foreground
        }
    }
}
#endif
