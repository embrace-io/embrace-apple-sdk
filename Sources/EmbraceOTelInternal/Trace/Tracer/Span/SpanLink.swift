//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

public protocol SpanLink {
    var context: SpanContext { get }
    var attributes: [String: AttributeValue] { get }
}

extension SpanData.Link: SpanLink { }
