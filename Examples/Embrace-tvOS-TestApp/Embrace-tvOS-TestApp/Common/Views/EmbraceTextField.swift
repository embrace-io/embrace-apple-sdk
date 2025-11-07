//
//  EmbraceTextField.swift
//  tvosTestApp
//
//

import SwiftUI

struct EmbraceTextField: View {
    let title: String
    @Binding var output: String
    let submitLabel: SubmitLabel
    let frameWidth: CGFloat
    
    var body: some View {
        TextField(title, text: $output)
            .font(.embraceFontLight(size: 30))
            .submitLabel(submitLabel)
            .frame(width: frameWidth)        
    }
}

#Preview {
    @Previewable @State var output: String = ""
    EmbraceTextField(title: "Title", output: $output, submitLabel: .continue, frameWidth: 500)
}
