//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import MetricKit

// MARK: - Data Structures

/// Root structure representing the MetricKit payload
struct MetricPayload: Codable {
    let latestApplicationVersion: String
    let includesMultipleApplicationVersions: Bool
    let timeStampBegin: Int
    let timeStampEnd: Int
    let metaData: MetaData?
    let signpostMetrics: [SignpostMetric]?
}

/// Metadata about the app and device
struct MetaData: Codable {
    let regionFormat: String
    let osVersion: String
    let deviceType: String
    let applicationBuildVersion: String
    let platformArchitecture: String
    let lowPowerModeEnabled: Bool
    let isTestFlightApp: Bool
    let pid: Int32
    let bundleIdentifier: String
}

/// Signpost metric data
struct SignpostMetric: Codable {
    let signpostName: String
    let signpostCategory: String
    let totalCount: Int
    let signpostIntervalData: SignpostIntervalData?
}

/// Interval data for a signpost
struct SignpostIntervalData: Codable {
    let histogrammedSignpostDuration: Histogram?
    let cumulativeCPUTime: Int
    let averageMemory: AverageMemory?
    let cumulativeLogicalWrites: Int
    let cumulativeHitchTimeRatio: Double
}

/// Histogram data structure
struct Histogram: Codable {
    let buckets: [HistogramBucket]
}

/// Individual histogram bucket
struct HistogramBucket: Codable {
    let bucketStart: Int
    let bucketEnd: Int
    let bucketCount: Int
}

/// Average memory measurement
struct AverageMemory: Codable {
    let averageMeasurement: Int
    let sampleCount: Int
    let standardDeviation: Double
}

// MARK: - Data Structure Extensions

extension MetaData {

    init?(from metaData: MXMetaData?) {
        guard let metaData = metaData else { return nil }

        if #available(iOS 14.0, *) {
            self.platformArchitecture = metaData.platformArchitecture
        } else {
            self.platformArchitecture = ""
        }

        if #available(iOS 17.0, *) {
            self.lowPowerModeEnabled = metaData.lowPowerModeEnabled
            self.isTestFlightApp = metaData.isTestFlightApp
            self.pid = metaData.pid
        } else {
            self.lowPowerModeEnabled = false
            self.isTestFlightApp = false
            self.pid = -1
        }

        // bundle identifier is special, it appeared in iOS 26 but is avaialble in the JSON.
        self.bundleIdentifier = metaData.dictionaryRepresentation()["bundleIdentifier"] as? String ?? ""

        self.regionFormat = metaData.regionFormat
        self.osVersion = metaData.osVersion
        self.deviceType = metaData.deviceType
        self.applicationBuildVersion = metaData.applicationBuildVersion
    }

}

extension Histogram {

    init?(histogram: MXHistogram<UnitDuration>?) {
        guard let histogram = histogram else { return nil }

        self.buckets = histogram.bucketEnumerator
            .compactMap { $0 as? MXHistogramBucket<UnitDuration> }
            .compactMap {
                HistogramBucket(
                    bucketStart: $0.bucketStart.nanosecondsValue,
                    bucketEnd: $0.bucketEnd.nanosecondsValue,
                    bucketCount: $0.bucketCount
                )
            }
    }
}

extension AverageMemory {

    init?(average: MXAverage<UnitInformationStorage>?) {
        guard let average = average else { return nil }

        self.averageMeasurement = average.averageMeasurement.bytesValue
        self.sampleCount = average.sampleCount
        self.standardDeviation = average.standardDeviation
    }
}

extension SignpostIntervalData {

    init?(intervalData: MXSignpostIntervalData?) {
        guard let intervalData = intervalData else { return nil }

        self.histogrammedSignpostDuration = Histogram(histogram: intervalData.histogrammedSignpostDuration)
        self.cumulativeCPUTime = intervalData.cumulativeCPUTime?.nanosecondsValue ?? 0
        self.averageMemory = AverageMemory(average: intervalData.averageMemory)
        self.cumulativeLogicalWrites = intervalData.cumulativeLogicalWrites?.bytesValue ?? 0

        if #available(iOS 15.0, *) {
            self.cumulativeHitchTimeRatio = intervalData.cumulativeHitchTimeRatio?.value ?? 0
        } else {
            self.cumulativeHitchTimeRatio = 0
        }
    }
}

extension MetricPayload {

    static let allowedSignpostCategories = ["EmbraceSDK"]

    init(payload: MXMetricPayload) {
        self.latestApplicationVersion = payload.latestApplicationVersion
        self.includesMultipleApplicationVersions = payload.includesMultipleApplicationVersions
        self.timeStampBegin = Int(payload.timeStampBegin.timeIntervalSince1970 * 1_000_000_000)
        self.timeStampEnd = Int(payload.timeStampEnd.timeIntervalSince1970 * 1_000_000_000)
        self.metaData = MetaData(from: payload.metaData)
        self.signpostMetrics = payload.signpostMetrics?.compactMap { signpost in
            // See EmbraceMetricKitSpan
            guard Self.allowedSignpostCategories.contains(signpost.signpostCategory) else {
                return nil
            }
            return SignpostMetric(
                signpostName: signpost.signpostName,
                signpostCategory: signpost.signpostCategory,
                totalCount: signpost.totalCount,
                signpostIntervalData: SignpostIntervalData(intervalData: signpost.signpostIntervalData)
            )
        }
    }
}

// MARK: - Unit Conversions

extension Measurement where UnitType == UnitDuration {
    /// Converts a duration measurement to nanoseconds (Int)
    var nanosecondsValue: Int {
        Int(converted(to: .nanoseconds).value)
    }
}

extension Measurement where UnitType == UnitInformationStorage {
    /// Converts a storage measurement to bytes (Int)
    var bytesValue: Int {
        Int(converted(to: .bytes).value)
    }
}
