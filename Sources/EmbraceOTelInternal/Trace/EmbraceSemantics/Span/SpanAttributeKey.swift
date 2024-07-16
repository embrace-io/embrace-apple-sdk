//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

enum SpanAttributeKey: String {
    case type = "emb.type"
    case isKey = "emb.key"
    case errorCode = "emb.error_code"
    case isPrivate = "emb.private"
}

enum SpanErrorAttributeKey: String {
    case message = "error.message"
    case code = "error.code"
}
