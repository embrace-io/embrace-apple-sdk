//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// Enum used to identify the `CaptureServices` provided by Embrace
public enum EmbraceCaptureService {
    case urlSession

    #if canImport(UIKit) && !os(watchOS)
        case tap
        case view
    #endif

    #if canImport(WebKit)
        case webView
    #endif

    case pushNotification
    case lowMemoryWarning
    case lowPowerMode
    case hang
}
