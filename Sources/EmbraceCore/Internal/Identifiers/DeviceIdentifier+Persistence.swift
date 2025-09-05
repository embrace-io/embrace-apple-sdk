//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

class DeviceIdentifierHelper {
    static func retrieve(fileURL: URL?) -> EmbraceIdentifier {

        // retrieve from file
        if let fileURL = fileURL,
            FileManager.default.fileExists(atPath: fileURL.path),
            let deviceId = try? String(contentsOf: fileURL),
            let uuid = UUID(uuidString: deviceId)
        {
            return EmbraceIdentifier(value: uuid)
        }

        // fallback to retrieve from Keychain
        let uuid = KeychainAccess.deviceId
        let deviceId = EmbraceIdentifier(value: uuid)

        // store in file
        if let fileURL = fileURL {
            do {
                let rootURL = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: fileURL)
                try uuid.uuidString.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                Embrace.logger.error("Error saving device identifier!:\n\(error.localizedDescription)")
            }
        }

        return deviceId
    }
}
