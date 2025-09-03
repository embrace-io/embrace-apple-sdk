//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceConfiguration
#endif

struct SessionLimits {

    let customSpans: SpanLimits
    var events: SpanEventLimits
    let links: SpanLinkLimits
    var logs: LogLimits

    init(
        customSpans: SpanLimits = SpanLimits(),
        events: SpanEventLimits = SpanEventLimits(),
        links: SpanLinkLimits = SpanLinkLimits(),
        logs: LogLimits = LogLimits()
    ) {
        self.customSpans = customSpans
        self.events = events
        self.links = links
        self.logs = logs
    }

    struct SpanLimits {
        let count: Int = 500
        let nameLength: Int = 128
        let events: SpanEventLimits = SpanEventLimits(count: 20, typeLimits: nil)
        let links: SpanLinkLimits = SpanLinkLimits(count: 20)
        let attributeCount: Int = 100
    }

    struct SpanEventLimits {
        let count: Int
        let nameLength: Int
        var typeLimits: SpanEventTypeLimits?
        let attributeCount: Int

        init(
            count: Int = 1000,
            nameLength: Int = 128,
            typeLimits: SpanEventTypeLimits? = SpanEventTypeLimits(),
            attributeCount: Int = 10
        ) {
            self.count = count
            self.nameLength = nameLength
            self.typeLimits = typeLimits
            self.attributeCount = attributeCount
        }
    }

    struct SpanLinkLimits {
        let count: Int
        let attributeCount: Int

        init(count: Int = 200, attributeCount: Int = 10) {
            self.count = count
            self.attributeCount = attributeCount
        }
    }

    struct LogLimits {
        var severityLimits: LogSeverityLimits = LogSeverityLimits()
        let attributeCount: Int = 100
    }
}
