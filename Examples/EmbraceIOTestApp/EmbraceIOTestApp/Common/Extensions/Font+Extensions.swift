//
//  Font+Extensions.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

extension Font {
    public static func embraceFontLight(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    public static func embraceFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
