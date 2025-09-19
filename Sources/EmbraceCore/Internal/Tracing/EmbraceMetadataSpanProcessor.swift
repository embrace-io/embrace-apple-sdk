//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

class EmbraceMetadataSpanProcessor: SpanProcessor {
    let isStartRequired: Bool = true
    let isEndRequired: Bool = true
    private let providers: [EmbraceMetadataProvider]

    init(providers: [EmbraceMetadataProvider]) {
        self.providers = providers
    }

    func onStart(parentContext: OpenTelemetryApi.SpanContext?, span: any OpenTelemetrySdk.ReadableSpan) {
        addProviderAttributes("start", span: span)
    }

    func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {
        addProviderAttributes("end", span: span)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
    }

    func forceFlush(timeout: TimeInterval?) {
    }
}

extension EmbraceMetadataSpanProcessor {

    private func addProviderAttributes(_ prefix: String, span: any OpenTelemetrySdk.ReadableSpan) {

        for provider in providers {
            let prefix = "-emb-md-\(prefix)-\(provider.type.name)."
            let atts = provider.provide()
            let updated = Dictionary(
                uniqueKeysWithValues: atts.compactMap { key, value in
                    if let newValue = AttributeValue(value) {
                        return (prefix + key, newValue)
                    }
                    return nil
                })
            span.setAttributes(updated)
        }
    }
}
