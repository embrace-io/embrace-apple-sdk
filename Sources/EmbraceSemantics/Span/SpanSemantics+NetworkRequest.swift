//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public extension SpanType {
    static let networkRequest = SpanType(performance: "network_request")
}

public extension SpanSemantics {
    struct NetworkRequest {
        public static let keyUrl = "url.full"
        public static let keyMethod = "http.request.method"
        public static let keyBodySize = "http.request.body.size"
        public static let keyTracingHeader = "emb.w3c_traceparent"
        public static let keyStatusCode = "http.response.status_code"
        public static let keyResponseSize = "http.response.body.size"
        public static let keyErrorType = "error.type"
        public static let keyErrorCode = "error.code"
        public static let keyErrorMessage = "error.message"
    }
}
