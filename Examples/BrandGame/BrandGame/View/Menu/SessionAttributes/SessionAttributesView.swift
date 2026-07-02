//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import SwiftUI

struct SessionAttributesView: View {
    @State private var property = Property()
    @State private var action: Action = .add
    @State private var appliesToAllAttributes: Bool = false
    @State private var showPopUp: Bool = false

    private var metadataLifespan: MetadataLifespan {
        return property.lifespan.toMetadataLifespan()
    }

    var body: some View {
        Form {
            Picker("Type", selection: $action) {
                ForEach(Action.allCases) { action in
                    Text(action.rawValue).tag(action)
                }
            }.pickerStyle(SegmentedPickerStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: -12, leading: 0, bottom: 0, trailing: 0))

            Section(header: Text("Property Details")) {
                Picker("Type", selection: $property.type) {
                    ForEach(AttributeType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                Picker("Lifespan", selection: $property.lifespan) {
                    ForEach(Lifespan.allCases) { lifespan in
                        Text(lifespan.rawValue).tag(lifespan)
                    }
                }

                if action == .delete {
                    Toggle(
                        isOn: $appliesToAllAttributes,
                        label: {
                            Text("\(action.rawValue) all?")
                        })
                }

                if !(action == .delete && appliesToAllAttributes) {
                    NoSpacesTextField("Key", text: $property.key)
                }

                if action != .delete {
                    NoSpacesTextField("Value", text: $property.value)
                }
            }

            Section {
                Button("Execute") {
                    execute()
                }
                .disabled(isExecuteDisabled())

                Button("Reset Fields", role: .destructive) {
                    resetFields()
                }
            }
        }
        .popUp("\(property.type.rawValue) was \(action.rawValue)ed", shouldShow: $showPopUp)
        .navigationBarTitle("Session Attributes", displayMode: .inline)
    }
}

// MARK: - Private Methods / Logic
extension SessionAttributesView {
    fileprivate func isExecuteDisabled() -> Bool {
        switch action {
        case .add, .update:
            return property.key.isEmpty || property.value.isEmpty
        case .delete:
            return property.key.isEmpty && !appliesToAllAttributes
        }
    }

    fileprivate func execute() {
        switch action {
        case .add, .update:
            setProperty()
        case .delete:
            deleteProperty()
        }
        showPopUp = true
        property.key = ""
        property.value = ""
    }

    fileprivate func setProperty() {
        switch property.type {
        case .resource:
            // TODO 7.0: Resource runtime mutation is not exposed on the EmbraceIO public surface
            // (resources are now provided at SDK setup via OTel options). Re-enable when/if
            // EmbraceIO exposes a runtime resource API.
            break
        case .sessionProperty:
            EmbraceIO.shared.setProperty(
                key: property.key,
                value: property.value,
                lifespan: metadataLifespan
            )
        }
    }

    fileprivate func deleteProperty() {
        switch property.type {
        case .resource:
            // TODO 7.0: Resource runtime mutation is not exposed on the EmbraceIO public surface
            // (resources are now provided at SDK setup via OTel options). Re-enable when/if
            // EmbraceIO exposes a runtime resource API.
            break
        case .sessionProperty:
            if appliesToAllAttributes {
                EmbraceIO.shared.removeAllProperties(lifespans: [metadataLifespan])
            } else {
                EmbraceIO.shared.setProperty(
                    key: property.key,
                    value: nil,
                    lifespan: metadataLifespan
                )
            }
        }
    }

    fileprivate func resetFields() {
        property = Property()
        action = .add
        appliesToAllAttributes = false
    }
}

// MARK: - Types
extension SessionAttributesView {
    fileprivate enum AttributeType: String, CaseIterable, Identifiable {
        case sessionProperty = "Session Property"
        case resource = "Resource"

        var id: String { self.rawValue }
    }

    fileprivate enum Lifespan: String, CaseIterable, Identifiable {
        case session = "Session"
        case process = "Process"
        case permanent = "Permanent"

        var id: String { self.rawValue }

        func toMetadataLifespan() -> MetadataLifespan {
            switch self {
            case .session:
                return .session
            case .process:
                return .process
            case .permanent:
                return .permanent
            }
        }
    }

    fileprivate enum Action: String, CaseIterable, Identifiable {
        case add = "Add"
        case update = "Update"
        case delete = "Delete"

        var id: String { self.rawValue }
    }

    fileprivate struct Property {
        var type: AttributeType = .sessionProperty
        var lifespan: Lifespan = .session
        var key: String = ""
        var value: String = ""
    }
}

#Preview {
    SessionAttributesView()
}
