//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
    import EmbraceStorageInternal
#endif

class PayloadUtils {
    static func fetchResources(
        from fetcher: EmbraceStorageMetadataFetcher,
        sessionId: EmbraceIdentifier?
    ) -> [EmbraceMetadata] {

        guard let sessionId = sessionId else {
            return []
        }

        return fetcher.fetchResourcesForSessionId(sessionId)
    }

    static func fetchCustomProperties(
        from fetcher: EmbraceStorageMetadataFetcher,
        sessionId: EmbraceIdentifier?
    ) -> [EmbraceMetadata] {

        guard let sessionId = sessionId else {
            return []
        }

        return fetcher.fetchCustomPropertiesForSessionId(sessionId)
    }
}
