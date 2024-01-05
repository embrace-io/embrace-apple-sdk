//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct MinigameView: View {

    @Environment(\.settings) var appSettings

    var body: some View {
        switch appSettings.selectedMinigame {
        case .bubble: BubbleMinigameView()
        case .reflex: ReflexMinigameView()
        case .simon: SimonMinigameView()
        }
    }
}
