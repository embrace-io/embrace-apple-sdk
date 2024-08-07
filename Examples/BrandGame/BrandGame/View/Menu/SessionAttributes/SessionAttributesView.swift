//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import EmbraceIO

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
                    Toggle(isOn: $appliesToAllAttributes, label: {
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
private extension SessionAttributesView {
    func isExecuteDisabled() -> Bool {
        switch action {
        case .add, .update:
            return property.key.isEmpty || property.value.isEmpty
        case .delete:
            return property.key.isEmpty && !appliesToAllAttributes
        }
    }

    func execute() {
        do {
            switch action {
            case .add:
                try addProperty()
            case .update:
                try updateProperty()
            case .delete:
                try deleteProperty()
            }
            showPopUp = true
            property.key = ""
            property.value = ""
        } catch let exception {
            print(exception.localizedDescription)
        }
    }

    func addProperty() throws {
        let metadata = Embrace.client?.metadata
        switch property.type {
        case .resource:
            try metadata?.addResource(
                key: property.key,
                value: property.value,
                lifespan: metadataLifespan
            )
        case .sessionProperty:
            try metadata?.addProperty(
                key: property.key,
                value: property.value,
                lifespan: metadataLifespan
            )
        }
    }

    func updateProperty() throws {
        let metadata = Embrace.client?.metadata
        switch property.type {
        case .resource:
            try metadata?.updateResource(
                key: property.key,
                value: property.value,
                lifespan: metadataLifespan
            )
        case .sessionProperty:
            try metadata?.updateProperty(
                key: property.key,
                value: property.value,
                lifespan: metadataLifespan
            )
        }
    }

    func deleteProperty () throws {
        let metadata = Embrace.client?.metadata
        switch property.type {
        case .resource:
            if appliesToAllAttributes {
                try metadata?.removeAllResources(lifespans: [metadataLifespan])
            } else {
                try metadata?.removeResource(
                    key: property.key,
                    lifespan: metadataLifespan
                )
            }
        case .sessionProperty:
            if appliesToAllAttributes {
                try metadata?.removeAllProperties(lifespans: [metadataLifespan])
            } else {
                try metadata?.removeProperty(
                    key: property.key,
                    lifespan: metadataLifespan
                )
            }
        }
    }

    func resetFields() {
        property = Property()
        action = .add
        appliesToAllAttributes = false
    }
}

// MARK: - Types
private extension SessionAttributesView {
    enum AttributeType: String, CaseIterable, Identifiable {
        case sessionProperty = "Session Property"
        case resource = "Resource"

        var id: String { self.rawValue }
    }

    enum Lifespan: String, CaseIterable, Identifiable {
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

    enum Action: String, CaseIterable, Identifiable {
        case add = "Add"
        case update = "Update"
        case delete = "Delete"

        var id: String { self.rawValue }
    }

    struct Property {
        var type: AttributeType = .sessionProperty
        var lifespan: Lifespan = .session
        var key: String = ""
        var value: String = ""
    }
}

#Preview {
    SessionAttributesView()
}
