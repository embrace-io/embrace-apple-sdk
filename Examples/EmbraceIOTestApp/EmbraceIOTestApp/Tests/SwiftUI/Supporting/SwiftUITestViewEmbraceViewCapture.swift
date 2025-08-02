//
//  SwiftUITestViewEmbraceViewCapture.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceIO

struct SwiftUITestViewEmbraceViewCapture: View {
    var attributes: [String: String] = [:]
    var loaded: Bool? = nil
    var body: some View {
        EmbraceTraceView(
            "MyEmbraceTraceView",
            attributes: attributes,
            contentComplete: loaded
        ) {
            Text("👀 Don't mind me!")
        }
    }
}
