//
//  MetadataTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk

class MetadataStartTest: PayloadTest {
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestItem]()
        let startSpanName = "emb-sdk-start"

        guard let startSpan = spans.first (where: { $0.name == startSpanName })
        else {
            testItems.append(.init(target: startSpanName, expected: "exists", recorded: "missing", result: .fail))
            return .init(result: .fail, testItems: testItems)
        }

        testItems.append(.init(target: startSpanName, expected: "exists", recorded: "exists", result: .pass))
        testItems.append(evaluate("emb.type", expecting: "perf", on: startSpan.attributes))

        return .init(result: testResult(from: testItems), testItems: testItems)
    }
}

class MetadataSetupTest: PayloadTest {
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestItem]()
        let setupSpanName = "emb-setup"

        guard let setupSpan = spans.first (where: { $0.name == setupSpanName })
        else {
            testItems.append(.init(target: setupSpanName, expected: "exists", recorded: "missing", result: .fail))
            return .init(result: .fail, testItems: testItems)
        }

        testItems.append(.init(target: setupSpanName, expected: "exists", recorded: "exists", result: .pass))
        testItems.append(evaluate("emb.type", expecting: "perf", on: setupSpan.attributes))
        testItems.append(evaluate("emb.private", expecting: "true", on: setupSpan.attributes))

        return .init(result: testResult(from: testItems), testItems: testItems)
    }
}

/*
 ▿ SpanData
   ▿ traceId : TraceId{traceId=9005c354b3cda4f2927a7ad46404d3a5}
     - idHi : 10377915684906444018
     - idLo : 10554883729325872037
   ▿ spanId : SpanId{spanId=230c2125bd03458b}
     - id : 2525429937016620427
   ▿ traceFlags : TraceFlags{sampled=true}
     - options : 1
   ▿ traceState : TraceState
     - entries : 0 elements
   ▿ parentSpanId : Optional<SpanId>
     ▿ some : SpanId{spanId=d4797e7d7727f1ee}
       - id : 15310407485557830126
   ▿ resource : Resource
     ▿ attributes : 25 elements
       ▿ 0 : 2 elements
         - key : "emb.device.disk_size"
         ▿ value : 494384795648
           - int : 494384795648
       ▿ 1 : 2 elements
         - key : "emb.app.bundle_version"
         ▿ value : 1
           - string : "1"
       ▿ 2 : 2 elements
         - key : "emb.device.is_jailbroken"
         ▿ value : false
           - string : "false"
       ▿ 3 : 2 elements
         - key : "os.name"
         ▿ value : iOS
           - string : "iOS"
       ▿ 4 : 2 elements
         - key : "emb.session.upload_index"
         ▿ value : 65
           - string : "65"
       ▿ 5 : 2 elements
         - key : "emb.os.build_id"
         ▿ value : 24B91
           - string : "24B91"
       ▿ 6 : 2 elements
         - key : "emb.process_identifier"
         ▿ value : c1798789
           - string : "c1798789"
       ▿ 7 : 2 elements
         - key : "emb.app.framework"
         ▿ value : 1
           - int : 1
       ▿ 8 : 2 elements
         - key : "emb.app.environment_detailed"
         ▿ value : si
           - string : "si"
       ▿ 9 : 2 elements
         - key : "emb.process_start_time"
         ▿ value : 1737992849280536064
           - int : 1737992849280536064
       ▿ 10 : 2 elements
         - key : "emb.app.build_id"
         ▿ value : F5D2BE177B6F3D148BB5759A7F8F560F
           - string : "F5D2BE177B6F3D148BB5759A7F8F560F"
       ▿ 11 : 2 elements
         - key : "device.model.identifier"
         ▿ value : arm64
           - string : "arm64"
       ▿ 12 : 2 elements
         - key : "emb.app.version"
         ▿ value : 1.0
           - string : "1.0"
       ▿ 13 : 2 elements
         - key : "emb.device_id"
         ▿ value : 4D8C676548E44CB285E80461560A0ECD
           - string : "4D8C676548E44CB285E80461560A0ECD"
       ▿ 14 : 2 elements
         - key : "service.name"
         ▿ value : com.embrace.EmbraceIOTestApp:EmbraceIOTestApp
           - string : "com.embrace.EmbraceIOTestApp:EmbraceIOTestApp"
       ▿ 15 : 2 elements
         - key : "emb.device.architecture"
         ▿ value : arm64e
           - string : "arm64e"
       ▿ 16 : 2 elements
         - key : "os.type"
         ▿ value : darwin
           - string : "darwin"
       ▿ 17 : 2 elements
         - key : "emb.process_pre_warm"
         ▿ value : false
           - bool : false
       ▿ 18 : 2 elements
         - key : "emb.sdk.version"
         ▿ value : 6.6.0
           - string : "6.6.0"
       ▿ 19 : 2 elements
         - key : "emb.os.variant"
         ▿ value : iOS
           - string : "iOS"
       ▿ 20 : 2 elements
         - key : "emb.app.environment"
         ▿ value : dev
           - string : "dev"
       ▿ 21 : 2 elements
         - key : "os.version"
         ▿ value : 18.2
           - string : "18.2"
       ▿ 22 : 2 elements
         - key : "telemetry.sdk.language"
         ▿ value : swift
           - string : "swift"
       ▿ 23 : 2 elements
         - key : "emb.device.locale"
         ▿ value : en_AR
           - string : "en_AR"
       ▿ 24 : 2 elements
         - key : "emb.device.timezone"
         ▿ value : America/Argentina/Catamarca
           - string : "America/Argentina/Catamarca"
   ▿ instrumentationScope : InstrumentationScopeInfo
     - name : "EmbraceOpenTelemetry"
     ▿ version : Optional<String>
       - some : "semver:6.6.0"
     - schemaUrl : nil
   - name : "emb-sdk-start"
   - kind : OpenTelemetryApi.SpanKind.internal
   ▿ startTime : 2025-01-27 15:47:34 +0000
     - timeIntervalSinceReferenceDate : 759685654.210005
   ▿ attributes : 1 element
     ▿ 0 : 2 elements
       - key : "emb.type"
       ▿ value : perf
         - string : "perf"
   - events : 0 elements
   - links : 0 elements
   - status : Status{statusCode=unset}
   ▿ endTime : 2025-01-27 15:47:34 +0000
     - timeIntervalSinceReferenceDate : 759685654.241609
   - hasRemoteParent : false
   - hasEnded : true
   - totalRecordedEvents : 0
   - totalRecordedLinks : 0
   - totalAttributeCount : 1
 */
