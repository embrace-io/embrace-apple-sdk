//
//  UploadedSessionPayloadTestPersonasView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import Combine
import EmbraceIO

struct UploadedSessionPayloadTestPersonasView: View {
    var addPersonaAction: (String, MetadataLifespan) -> Void
    var removeAllAction: () -> Void
    @State private var persona: String = "Testing"
    @State private var lifespan: MetadataLifespan = .session

    var body: some View {
        VStack(alignment: .leading) {
            Text("Persona")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.leading, .bottom], 5)
            TextField("Testing", text: $persona)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing,], 5)
                .textFieldStyle(RoundedStyle())
                .accessibilityIdentifier("SessionTests_Persona")
                .padding(.bottom, 5)
            Text("Lifespan")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.leading, .bottom], 5)
            Picker("", selection: $lifespan) {
                ForEach(MetadataLifespan.allCases, id: \.self) { option in
                    Text(option.text)
                        .accessibilityIdentifier(option.identifier)
                        .tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 20)
            HStack {
                Spacer()
                Button {
                    addPersonaAction(persona, lifespan)
                } label: {
                    Text("Add Persona")
                        .frame(height: 40)
                }
                .disabled(persona.isEmpty)
                .accessibilityIdentifier("SessionTests_Personas_AddButton")
                Spacer()
            }
            HStack {
                Spacer()
                Button {
                    removeAllAction()
                } label: {
                    Text("Remove All Personas")
                        .frame(height: 40)
                }
                .accessibilityIdentifier("SessionTests_Personas_RemoveAllButton")
                Spacer()
            }
        }
    }
}

extension MetadataLifespan: CaseIterable {
    public static var allCases: [MetadataLifespan] {
        [.permanent, .process, .session]
    }

    var text: String {
        switch self {
        case .permanent:
            "permanent"
        case .process:
            "process"
        case .session:
            "session"
        }
    }

    var identifier: String {
        switch self {
        case .permanent:
            "MetadataLifespan_permanent"
        case .process:
            "MetadataLifespan_process"
        case .session:
            "MetadataLifespan_session"
        }
    }
}

#Preview {
    return UploadedSessionPayloadTestPersonasView { key, value in
        print("Added persona: \(key) - lifespan: \(value.text)")
    } removeAllAction: {
        print("Remove All")
    }
}
