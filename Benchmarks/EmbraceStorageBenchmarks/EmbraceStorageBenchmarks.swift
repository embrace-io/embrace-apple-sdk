//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Benchmark
import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal
import OpenTelemetryApi

let benchmarks = {
    Benchmark("Perform Migrations", configuration: .init(metrics: .all)) { benchmark in
        let tmpURL = FileManager.default.temporaryDirectory.appending(path: #file)

        for i in benchmark.scaledIterations {
            var storage: EmbraceStorage? = try? EmbraceStorage(
                options: .init(baseUrl: tmpURL,
                               fileName: "storage_migrations.sqlite"),
                logger: .noop
            )
            try? storage?.performMigration()

            storage = nil

            try FileManager.default.removeItem(at: tmpURL)
        }
    }

    Benchmark("Insert SpanRecord") { benchmark in
        let tmpURL = FileManager.default.temporaryDirectory.appending(path: #file)

        do {
            let storage = try EmbraceStorage(
                options: .init(baseUrl: tmpURL,
                               fileName: "span_insert.sqlite"),
                logger: .noop
            )
            try storage.performMigration()

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

            try FileManager.default.removeItem(at: tmpURL)
        } catch let e {
            throw e
        }
    }
}
