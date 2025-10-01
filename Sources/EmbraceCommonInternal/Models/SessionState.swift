//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum SessionState: String, Sendable {
    case foreground
    case background
    case unknown
}

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    extension SessionState {
        public init?(appState: UIApplication.State) {
            if appState == .background {
                self = .background
            } else {
                self = .foreground
            }
        }
    }
#endif
