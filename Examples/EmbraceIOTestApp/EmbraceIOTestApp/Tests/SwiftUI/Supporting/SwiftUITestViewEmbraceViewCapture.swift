//
//  SwiftUITestViewEmbraceViewCapture.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceIO

struct SwiftUITestViewEmbraceViewCapture: View {
    var body: some View {
        EmbraceTraceView(
            "MyEmbraceTraceView"
        ) {
            Text("👀 Don't mind me!")
        }
    }
}
