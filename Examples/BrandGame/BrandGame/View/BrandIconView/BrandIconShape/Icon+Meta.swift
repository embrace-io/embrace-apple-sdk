//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

enum IconShape {
    static let aspectRatio = 300.0 / 215.0
}

enum IconComponent: CaseIterable {
    case leftBracket
    case leftDot
    case rightDot
    case rightBracket
}

extension Array where Element == IconComponent {
    static var all: Self {
        IconComponent.allCases
    }

    static var left: Self {
        [.leftBracket, .leftDot]
    }

    static var right: Self {
        [.rightDot, .rightBracket]
    }

    static var none: Self {
        []
    }
}
