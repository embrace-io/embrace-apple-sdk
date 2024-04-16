//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct RequestResponseDetail: View {
    let information: String

    var body: some View {
        ScrollView {
            Text(information)
                .padding()
        }
        .navigationTitle("Details")
    }
}

#Preview {
    RequestResponseDetail(information: "")
}
