//
//  SwiftUITestViewEmbraceViewCapture.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct SwiftUITestViewEmbraceViewCapture: View {
    var attributes: [String: String] = [:]
    var contentComplete: Bool = false
    @State private var onLoaded: Bool = false
    var body: some View {
        EmbraceTraceView(
            "MyEmbraceTraceView",
            attributes: attributes,
            trackBodyEvaluations: true,
            contentComplete: onLoaded
        ) {
            Text("👀 Don't mind me!")
        }
        .onAppear {
            if contentComplete {
                onLoaded = true
            }
        }
    }
}
