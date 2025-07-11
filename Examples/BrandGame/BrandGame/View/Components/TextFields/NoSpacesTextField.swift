//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct NoSpacesTextField: View {
    @Binding var text: String
    var placeholder: String
    private let replacementChar: String
    private let autocorrectionEnabled: Bool

    init(
        _ placeholder: String,
        text: Binding<String>,
        replacementChar: String = "_",
        autocorrectionEnabled: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.replacementChar = replacementChar
        self.autocorrectionEnabled = autocorrectionEnabled
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .onChange(of: text) { newValue, oldValue in
                let modifiedString = newValue.replacingOccurrences(of: " ", with: replacementChar)
                if modifiedString != oldValue {
                    text = modifiedString
                }
            }
        #if !os(macOS)
            .textInputAutocapitalization(.never)
        #endif
            .disableAutocorrection(!autocorrectionEnabled)
    }
}
