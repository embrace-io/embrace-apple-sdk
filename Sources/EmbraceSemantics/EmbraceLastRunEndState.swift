//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Used to determine the end state of the previous app run.
public enum EmbraceLastRunEndState: Int {
    /// Last end state can't be determined
    case unavailable

    /// Last app run ended in a crash
    case crash

    /// Last app run ended cleanly
    case cleanExit
}
