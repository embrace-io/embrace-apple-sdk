//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import OpenTelemetryApi

public extension SpanType {
    static let networkRequest = SpanType(performance: "network_request")
}

public extension SpanSemantics {
    struct NetworkRequest {
        public static let keyUrl = SemanticAttributes.urlFull.rawValue
        public static let keyMethod = SemanticAttributes.httpRequestMethod.rawValue
        public static let keyBodySize = SemanticAttributes.httpRequestBodySize.rawValue
        public static let keyTracingHeader = "emb.w3c_traceparent"
        public static let keyStatusCode = SemanticAttributes.httpResponseStatusCode.rawValue
        public static let keyResponseSize = SemanticAttributes.httpResponseBodySize.rawValue
        public static let keyErrorType = "error.type"
        public static let keyErrorCode = "error.code"
        public static let keyErrorMessage = "error.message"
    }
}
