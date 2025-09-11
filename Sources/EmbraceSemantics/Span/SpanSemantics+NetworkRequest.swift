//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanType {
    public static let networkRequest = SpanType(performance: "network_request")
}

extension SpanSemantics {
    public struct NetworkRequest {
        public static let keyUrl = SemanticConventions.Url.full.rawValue
        public static let keyMethod = SemanticConventions.Http.requestMethod.rawValue
        public static let keyBodySize = SemanticConventions.Http.requestBodySize.rawValue
        public static let keyTracingHeader = "emb.w3c_traceparent"
        public static let keyStatusCode = SemanticConventions.Http.responseStatusCode.rawValue
        public static let keyResponseSize = SemanticConventions.Http.responseBodySize.rawValue
        public static let keyErrorType = "error.type"
        public static let keyErrorCode = "error.code"
        public static let keyErrorMessage = "error.message"
    }
}
