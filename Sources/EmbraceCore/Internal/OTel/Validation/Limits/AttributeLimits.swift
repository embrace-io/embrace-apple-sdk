//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Length limits applied to attribute keys and values, for each signal source.
/// Attributes from `.sdk` signals have no limits.
struct AttributeLimits {

    var user: AttributeLengthLimits
    var captureService: AttributeLengthLimits

    init(
        user: AttributeLengthLimits = AttributeLengthLimits(),
        captureService: AttributeLengthLimits = AttributeLengthLimits(keyLength: nil, valueLength: nil)
    ) {
        self.user = user
        self.captureService = captureService
    }

    /// Returns the limits for the given source, or `nil` if the source has no limits.
    func limits(for source: EmbraceOTelSignalSource) -> AttributeLengthLimits? {
        switch source {
        case .user: return user
        case .captureService: return captureService
        case .sdk: return nil
        }
    }
}

/// Length limits for attribute keys and values. `nil` means no truncation.
struct AttributeLengthLimits {
    let keyLength: Int?
    let valueLength: Int?

    init(keyLength: Int? = 128, valueLength: Int? = 1024) {
        self.keyLength = keyLength
        self.valueLength = valueLength
    }
}
