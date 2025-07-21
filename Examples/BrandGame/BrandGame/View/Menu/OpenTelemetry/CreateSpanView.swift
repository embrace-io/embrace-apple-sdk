//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import SwiftUI

struct CreateSpanView: View {
    private let tracer: Tracer
    @State private var name: String = ""
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var attributes: [Attribute] = []
    @State private var keyAttr: String = ""
    @State private var valueAttr: String = ""
    @State private var showPopup = false

    init(tracer: Tracer) {
        self.tracer = tracer
    }

    var body: some View {
        Form {
            Section(header: Text("Span Details")) {
                TextField("Name", text: $name)

                DatePicker(
                    "Start Time",
                    selection: $startTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    "End Time",
                    selection: $endTime,
                    in: startTime...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section(header: Text("Attributes")) {
                ForEach($attributes, id: \.self) { attribute in
                    AttributeView(attribute: attribute)
                }

                VStack {
                    HStack {
                        TextField("", text: $keyAttr)
                        Divider()
                        TextField("", text: $valueAttr)
                        Button(
                            action: {
                                guard !keyAttr.isEmpty && !valueAttr.isEmpty else {
                                    return
                                }
                                attributes.append(.init(key: keyAttr, value: valueAttr).pruned())
                                keyAttr = ""
                                valueAttr = ""
                            },
                            label: {
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.blue)
                            })
                    }
                }
            }

            Button("Create Span") {
                createSpan()
            }.disabled(!isValidForm())

            Button("Clear Form", role: .destructive) {
                DispatchQueue.main.async {
                    clearFields()
                }
            }
        }.popUp("Span was created ✅", shouldShow: $showPopup)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationBarTitle("Create Span")
    }

    func removeAttributes(at offsets: IndexSet) {
        attributes.remove(atOffsets: offsets)
    }

    private func isValidForm() -> Bool {
        guard !name.isEmpty else {
            return false
        }
        guard startTime <= endTime else {
            return false
        }
        return true
    }

    private func createSpan() {
        let spanBuilder = tracer.spanBuilder(spanName: name)
        attributes.forEach { attribute in
            let attribute = attribute.pruned()
            spanBuilder.setAttribute(key: attribute.key, value: attribute.value)
        }
        spanBuilder.setStartTime(time: startTime)
        let span = spanBuilder.startSpan()
        span.end(time: endTime)
        showPopup = true
    }

    private func clearFields() {
        name = ""
        startTime = .now
        endTime = .now
        attributes.removeAll()
    }
}

struct AttributeView: View {
    @Binding var attribute: Attribute

    var body: some View {
        HStack {
            TextField("Key", text: $attribute.key)
            TextField("Value", text: $attribute.value)
        }
    }
}

struct Attribute: Hashable {
    private let uuid: UUID = .init()
    var key: String = ""
    var value: String = ""

    func pruned() -> Attribute {
        Attribute(
            key: key.replacingOccurrences(of: " ", with: "_"),
            value: value.replacingOccurrences(of: " ", with: "_")
        )
    }

    var id: String {
        uuid.uuidString
    }
}

#Preview {
    CreateSpanView(
        tracer: OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: "#preview",
            instrumentationVersion: nil
        )
    )
}
