//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import Apollo

extension ApolloClient {

    public static func example(queue: OperationQueue, endpointURL: URL) -> ApolloClient {
        var sessionConfiguration: URLSessionConfiguration = .default
        sessionConfiguration.timeoutIntervalForRequest = 30.0
        let sessionClient = URLSessionClient(
          sessionConfiguration: sessionConfiguration,
          callbackQueue: queue
        )

        let cache = InMemoryNormalizedCache()

        let store = ApolloStore(cache: InMemoryNormalizedCache())

        let transport = RequestChainNetworkTransport(
            interceptorProvider: DefaultInterceptorProvider(client: sessionClient, store: store),
            endpointURL: endpointURL
        )

        return ApolloClient(networkTransport: transport, store: store)
    }

}
