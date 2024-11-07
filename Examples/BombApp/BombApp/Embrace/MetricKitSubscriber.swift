//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import MetricKit
import EmbraceIO

class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricKitSubscriber()

    static func start() {
        MXMetricManager.shared.add(MetricKitSubscriber.shared)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        let jsons: [String] = payloads.compactMap {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: $0.dictionaryRepresentation(), options: []) else {
                return nil
            }

            return String(data: jsonData, encoding: .utf8)
        }
        Embrace.client?.log(
            "[MetricKit] - Metrics",
            severity: .error,
            timestamp: .now,
            attributes: getAttributes(fromJsons: jsons, method: "MXMetricPayload"),
            stackTraceBehavior: .notIncluded
        )
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let jsons: [String] = payloads.compactMap {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: $0.dictionaryRepresentation(), options: []) else {
                return nil
            }

            return String(data: jsonData, encoding: .utf8)
        }
        Embrace.client?.log(
            "[MetricKit] - Diagnostics",
            severity: .error,
            timestamp: .now,
            attributes: getAttributes(fromJsons: jsons, method: "MXDiagnosticPayload"),
            stackTraceBehavior: .notIncluded
        )
    }

    private func getAttributes(fromJsons jsons: [String], method: String) -> [String: String] {
        var attributes: [String: String] = [:]
        for (index, json) in jsons.enumerated() {
            attributes["json_\(index)"] = json
        }
        attributes["method"] = method
        return attributes
    }
}
