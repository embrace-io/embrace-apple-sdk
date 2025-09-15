//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    /// Used for Embrace Log messages. Use this type for common application logs
    public static let message = EmbraceType(system: "log")

    /// Used for exception messages
    public static let exception = EmbraceType(system: "exception")

    /// Used for internal messages about the operation of the Embrace SDK itself
    /// * Note: This should be used for observation of the Embrace SDK only.
    public static let `internal` = EmbraceType(system: "internal")
}
