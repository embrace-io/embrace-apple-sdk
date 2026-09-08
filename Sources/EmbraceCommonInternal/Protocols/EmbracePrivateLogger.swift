//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// Allows sending logs meant for Embrace's own diagnostics.
///
/// These logs are uploaded right away instead of going through the regular log pipeline,
/// which means they are never persisted nor forwarded to processors or exporters set by
/// the user of the SDK.
package protocol EmbracePrivateLogger: AnyObject {

    /// Sends a log meant for Embrace's own diagnostics.
    /// - Parameter message: The body of the log.
    func sendPrivateLog(_ message: String)
}
