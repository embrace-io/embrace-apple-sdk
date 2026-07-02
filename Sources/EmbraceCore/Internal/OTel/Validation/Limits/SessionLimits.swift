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
        let count: Int
        let nameLength: Int
        let attributeCount: Int

        init(
            count: Int = 500,
            nameLength: Int = 128,
            attributeCount: Int = 100
        ) {
            self.count = count
            self.nameLength = nameLength
            self.attributeCount = attributeCount
        }
    }

    struct SpanEventLimits {
        let sessionSpanEventCount: Int
        let customSpanEventCount: Int
        let nameLength: Int
        var typeLimits: SpanEventTypeLimits?
        let attributeCount: Int

        init(
            sessionSpanEventCount: Int = 1000,
            customSpanEventCount: Int = 20,
            nameLength: Int = 128,
            typeLimits: SpanEventTypeLimits? = SpanEventTypeLimits(),
            attributeCount: Int = 10
        ) {
            self.sessionSpanEventCount = sessionSpanEventCount
            self.customSpanEventCount = customSpanEventCount
            self.nameLength = nameLength
            self.typeLimits = typeLimits
            self.attributeCount = attributeCount
        }
    }

    struct SpanLinkLimits {
        let sessionSpanLinkCount: Int
        let customSpanLinkCount: Int
        let attributeCount: Int

        init(
            sessionSpanLinkCount: Int = 200,
            customSpanLinkCount: Int = 20,
            attributeCount: Int = 10
        ) {
            self.sessionSpanLinkCount = sessionSpanLinkCount
            self.customSpanLinkCount = customSpanLinkCount
            self.attributeCount = attributeCount
        }
    }

    struct LogLimits {
        var severityLimits: LogSeverityLimits
        let attributeCount: Int

        init(
            severityLimits: LogSeverityLimits = LogSeverityLimits(),
            attributeCount: Int = 100
        ) {
            self.severityLimits = severityLimits
            self.attributeCount = attributeCount
        }
    }
}
