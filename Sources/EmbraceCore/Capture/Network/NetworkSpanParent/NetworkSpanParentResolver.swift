//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Chooses the parent of a network span.
enum NetworkSpanParentResolver {

    enum Source: Equatable {
        /// Chosen by the requests data source.
        case dataSource
        /// The span named in the request's `traceparent` header.
        case header
        /// The network span parent set by the app.
        case networkSpanParent
        /// No parent; the network span starts a new trace.
        case none
    }

    struct Resolution {
        let context: EmbraceSpanContext?
        let source: Source
    }

    /// Resolves the parent of a network span. The first rule that applies wins:
    /// 1. The data source returned `.parent` with a valid context, or `.noParent`.
    /// 2. The request has a well-formed `traceparent` header.
    /// 3. A network span parent is set.
    /// 4. No parent.
    ///
    /// A `.parent` context whose identifiers can't refer to a span is treated as `.default`.
    ///
    /// - Parameters:
    ///   - decision: The data source's decision, or `.default` if there's no data source.
    ///   - header: The request's parsed `traceparent` header, if it has a well-formed one.
    ///   - networkSpanParent: The context of the network span parent set by the app, if any.
    ///   - logger: Used to warn about invalid `.parent` contexts.
    static func resolve(
        decision: EmbraceNetworkSpanParent,
        header: W3C.ParsedTraceparent?,
        networkSpanParent: EmbraceSpanContext?,
        logger: InternalLogger? = Embrace.logger
    ) -> Resolution {
        switch decision {
        case .noParent:
            return Resolution(context: nil, source: .dataSource)

        case .parent(let context):
            if context.isValid {
                let normalized = EmbraceSpanContext(
                    spanId: EmbraceSpanContext.normalize(context.spanId),
                    traceId: EmbraceSpanContext.normalize(context.traceId)
                )
                return Resolution(context: normalized, source: .dataSource)
            }

            logger?.warning(
                "Ignoring invalid network span parent returned by the requests data source: span id '\(context.spanId)', trace id '\(context.traceId)'. The default parent is used instead."
            )

        case .default:
            break
        }

        if let header {
            return Resolution(context: header.context, source: .header)
        }

        if let networkSpanParent {
            return Resolution(context: networkSpanParent, source: .networkSpanParent)
        }

        return Resolution(context: nil, source: .none)
    }
}
