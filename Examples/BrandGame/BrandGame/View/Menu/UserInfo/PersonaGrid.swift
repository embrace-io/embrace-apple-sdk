//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import SwiftUI

struct PersonaGrid: View {

    let lifespan: MetadataLifespan
    @ObservedObject var user: UserInfo.EmbraceUser

    var body: some View {
        Grid(verticalSpacing: 6.0) {
            ForEach(personaGridRows(), id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { personaOption in
                        PillText(
                            personaOption,
                            selected: user.hasPersona(personaOption),
                            style: colorForPersona(persona: personaOption)
                        ).onTapGesture {
                            user.toggle(persona: personaOption, lifespan: lifespan)
                        }
                    }
                }
            }
        }
    }

    func personaGridRows(size: Int = 3) -> [[String]] {
        let count = Self.quickPersonas.count

        return stride(from: 0, to: count, by: size).map {
            Array(Self.quickPersonas[$0..<Swift.min($0 + size, count)])
        }
    }

    func colorForPersona(persona: String) -> Color {
        let idx = persona.count % Self.personaColors.count
        return Self.personaColors[idx]
    }
}

extension PersonaGrid {
    static var quickPersonas: [String] {
        ["free", "preview", "subscriber", "payer", "guest", "pro", "mvp", "vip"]
    }

    static var personaColors: [Color] {
        [
            Color.embraceLead,
            Color.embracePink,
            Color.embracePurple,
            Color.embraceSilver
        ]
    }
}

#Preview {
    PersonaGrid(lifespan: .session, user: .init())
}
