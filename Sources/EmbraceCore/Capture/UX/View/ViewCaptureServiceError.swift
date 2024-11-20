//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum ViewCaptureServiceError: Error, Equatable {
    /// This error means the SDK was setup without a `ViewCaptureService`.
    case serviceNotFound(_ description: String)

    /// This error means the `ViewCaptureService.Options` was configured with `instrumentFirstRender` as `false`.
    case firstRenderInstrumentationDisabled(_ description: String)

    /// This error could means the `time-to-first-render` /  `time-to-interactive` span has already ended,
    /// so no child span can be added.
    case parentSpanNotFound(_ description: String)
}

extension ViewCaptureServiceError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .serviceNotFound:
            return -1
        case .firstRenderInstrumentationDisabled:
            return -2
        case .parentSpanNotFound:
            return -3
        }
    }

    public var errorDescription: String? {
        switch self {
        case .serviceNotFound(let description):
            return description
        case .firstRenderInstrumentationDisabled(let description):
            return description
        case .parentSpanNotFound(let description):
            return description
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
