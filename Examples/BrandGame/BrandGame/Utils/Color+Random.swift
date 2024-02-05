//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
