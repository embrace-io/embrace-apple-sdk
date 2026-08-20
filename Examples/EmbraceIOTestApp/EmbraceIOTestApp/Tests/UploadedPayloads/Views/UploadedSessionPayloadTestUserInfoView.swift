//
//  UploadedSessionPayloadTestUserInfoView.swift
//  EmbraceIOTestApp
//
//

import Combine
import EmbraceIO
import SwiftUI

struct UploadedSessionPayloadTestUserInfoView: View {
    @Binding var identifier: String
    var removeAllAction: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("User Description")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.leading, .bottom], 5)
            TextField("User Identifier", text: $identifier)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing], 5)
                .textFieldStyle(RoundedStyle())
                .accessibilityIdentifier("SessionTests_UserInfo_Identifier")
                .padding(.bottom, 20)
            HStack {
                Spacer()
                Button {
                    removeAllAction()
                } label: {
                    Text("Remove All User Properties")
                        .frame(height: 40)
                }
                .accessibilityIdentifier("SessionTests_UserInfo_RemoveAllButton")
                Spacer()
            }
        }
    }
}

#Preview {
    @Previewable @State var identifier: String = ""

    return UploadedSessionPayloadTestUserInfoView(
        identifier: $identifier
    ) {

    }
}
