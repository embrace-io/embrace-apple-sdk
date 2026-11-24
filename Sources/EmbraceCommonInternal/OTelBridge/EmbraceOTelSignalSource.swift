//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Who generated an OTel signal.
package enum EmbraceOTelSignalSource {
    /// Signals created by users of the SDK through the public API.
    case user

    /// Signals created by a `CaptureService`.
    case captureService

    /// Signals created by the SDK itself.
    case sdk
}
