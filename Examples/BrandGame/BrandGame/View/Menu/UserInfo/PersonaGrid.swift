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
                    ForEach(row) { personaOption in
                        PillText(
                            personaOption.rawValue,
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

    func personaGridRows(size: Int = 3) -> [[PersonaTag]] {
        let count = Self.quickPersonas.count

        return stride(from: 0, to: count, by: size).map {
            Array(Self.quickPersonas[$0..<Swift.min($0 + size, count)])
        }
    }

    func colorForPersona(persona: PersonaTag) -> Color {
        let idx = persona.rawValue.count % Self.personaColors.count
        return Self.personaColors[idx]
    }
}

extension PersonaGrid {
    static var quickPersonas: [PersonaTag] {
        [
            PersonaTag.free,
            PersonaTag.preview,
            PersonaTag.subscriber,
            PersonaTag.payer,
            PersonaTag.guest,
            PersonaTag.pro,
            PersonaTag.mvp,
            PersonaTag.vip,
        ]
    }

    static var personaColors: [Color] {
        [
            Color.embraceLead,
            Color.embracePink,
            Color.embracePurple,
            Color.embraceSilver,
        ]
    }
}

#Preview {
    PersonaGrid(lifespan: .session, user: .init())
}
