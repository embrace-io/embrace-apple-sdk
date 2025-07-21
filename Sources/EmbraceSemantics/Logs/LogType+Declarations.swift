//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

// MARK: - System
extension LogType {

    /// Used for Embrace Log messages. Use this type for common application logs
    public static let message = LogType(system: "log")

    /// Used for exception messages
    public static let exception = LogType(system: "exception")

    /// Used to leave small messages to hint the path a user has taken.
    public static let breadcrumb = LogType(system: "breadcrumb")

    /// Used for internal messages about the operation of the Embrace SDK itself
    /// * Note: This should be used for observation of the Embrace SDK only.
    public static let `internal` = LogType(system: "internal")
}
