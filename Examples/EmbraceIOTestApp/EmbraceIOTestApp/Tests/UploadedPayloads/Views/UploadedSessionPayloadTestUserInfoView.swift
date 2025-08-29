//
//  UploadedSessionPayloadTestUserInfoView.swift
//  EmbraceIOTestApp
//
//

import Combine
import EmbraceIO
import SwiftUI

struct UploadedSessionPayloadTestUserInfoView: View {
    @Binding var username: String
    @Binding var email: String
    @Binding var identifier: String
    var removeAllAction: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("User Name")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.leading, .bottom], 5)
            TextField("User Name", text: $username)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing], 5)
                .textFieldStyle(RoundedStyle())
                .accessibilityIdentifier("SessionTests_UserInfo_Username")
                .padding(.bottom, 5)
            Text("User Email")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.leading, .bottom], 5)
            TextField("User Email", text: $email)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing], 5)
                .textFieldStyle(RoundedStyle())
                .accessibilityIdentifier("SessionTests_UserInfo_Email")
                .padding(.bottom, 5)
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
    @Previewable @State var username: String = ""
    @Previewable @State var email: String = ""
    @Previewable @State var identifier: String = ""

    return UploadedSessionPayloadTestUserInfoView(
        username: $username,
        email: $email,
        identifier: $identifier
    ) {

    }
}
