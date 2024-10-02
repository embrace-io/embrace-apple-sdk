//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Benchmark
import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal
import OpenTelemetryApi

func removeTempDirectory() throws {
    try FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appending(path: #file))
}

let benchmarks = {
    Benchmark("Insert SpanRecords",
              configuration: .init(metrics: .all, teardown: removeTempDirectory)
    ) { benchmark in
        let tmpURL = FileManager.default.temporaryDirectory

        let storage = try! EmbraceStorage(
            options: .init(baseUrl: tmpURL.appending(path: #file),
                           fileName: "benchmarks.sqlite"),
            logger: .noop
        )
        try! storage.performMigration()

        let data = "This is some data".data(using: .utf8)!
        let date = Date()
        for i in benchmark.scaledIterations {
            try storage.upsertSpan(
                SpanRecord(
                    id: SpanId.random().hexString,
                    name: "benchmark - \(benchmark.name) #\(i)",
                    traceId: TraceId.random().hexString,
                    type: .performance,
                    data: data,
                    startTime: date
                )
            )
        }

        try FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appending(path: #file))
    }
}
