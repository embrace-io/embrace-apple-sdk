//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceSemantics {

    /// These are the expected values for the `emb.type` attribute
    public enum SpanType: String {

        /// Span to map the existing Embrace "session" object.
        case session

        case performance
        case ux
    }
}
