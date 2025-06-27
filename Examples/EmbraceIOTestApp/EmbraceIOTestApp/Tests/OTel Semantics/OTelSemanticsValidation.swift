//
//  OTelSemanticsValidation.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetryApi

struct OTelSemanticsValidation {
    /// Validates that the Attribute Names in the array conform to OTel Semantic Conventions 1.34.0: https://opentelemetry.io/docs/specs/semconv/general/naming/
    static func validateAttributeNames(_ attributes: [String: AttributeValue]) -> [TestReportItem] {
        var testItems = [TestReportItem]()
        let names = attributes.keys.sorted()

        for name in names {
            /// Not a FAIL but OTel recommends names to be lowercase only.
            /// https://opentelemetry.io/docs/specs/semconv/general/naming/#general-naming-considerations
            if name.containsUppercase() {
                testItems.append(.init(target: "Attribute: \(name)", expected: "only lowercase", recorded: "contains uppercase", result: .warning))
            }

            let components = name.components(separatedBy: ".")
            if components.count > 1 {
                switch components[0].lowercased() {
                case "otel":
                    /// Attributes using "otel." namespace are reserved by OpenTelemetry and must be approved as part of OTel Specification.
                    /// https://opentelemetry.io/docs/specs/semconv/general/naming/#otel-namespace
                    testItems.append(.init(target: "Attribute: \(name)", expected: "Not use otel namespace", recorded: "Uses otel namespace", result: .fail))
                default:
                    break
                }
            }
        }

        return testItems
    }
}
