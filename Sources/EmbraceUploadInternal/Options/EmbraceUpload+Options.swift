//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension EmbraceUpload {
    /// Class used to configure a EmbraceUpload instance
    public class Options {

        public let endpoints: EndpointOptions

        public let cache: CacheOptions

        public let metadata: MetadataOptions

        public let redundancy: RedundancyOptions

        public let urlSessionConfiguration: URLSessionConfiguration

        /// Transport used to send the uploads. When `nil`, a `URLSession` created with `urlSessionConfiguration` is used.
        package let transport: EmbraceUploadTransport?

        public convenience init(
            endpoints: EndpointOptions,
            cache: CacheOptions,
            metadata: MetadataOptions,
            redundancy: RedundancyOptions = RedundancyOptions(),
            urlSessionConfiguration: URLSessionConfiguration? = nil
        ) {
            self.init(
                endpoints: endpoints,
                cache: cache,
                metadata: metadata,
                redundancy: redundancy,
                urlSessionConfiguration: urlSessionConfiguration,
                transport: nil
            )
        }

        package init(
            endpoints: EndpointOptions,
            cache: CacheOptions,
            metadata: MetadataOptions,
            redundancy: RedundancyOptions = RedundancyOptions(),
            urlSessionConfiguration: URLSessionConfiguration? = nil,
            transport: EmbraceUploadTransport?
        ) {
            self.endpoints = endpoints
            self.cache = cache
            self.metadata = metadata
            self.redundancy = redundancy
            self.urlSessionConfiguration = urlSessionConfiguration ?? Options.defaultUrlSessionConfiguration()
            self.transport = transport
        }

        private class func defaultUrlSessionConfiguration() -> URLSessionConfiguration {
            let config = URLSessionConfiguration.default

            config.urlCache = URLCache(
                memoryCapacity: (4 * 1024 * 1024),  // 4 MB Memory Cache
                diskCapacity: (20 * 1024 * 1024),  // 20 MB Disk Cache
                diskPath: "embrace"
            )

            return config
        }
    }
}
