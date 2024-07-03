//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct BrowserView: View {
    @State private var urlString: String
    @State private var webView: WebView

    init(urlString: String = "https://embrace.io") {
        self.urlString = urlString
        self.webView = WebView(urlString: .constant(urlString))
    }

    var body: some View {
        VStack {
            webView
            HStack {
                TextField("Enter URL", text: $urlString, onCommit: {
                    loadURL()
                }).keyboardType(.URL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                Button {
                    loadURL()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(maxWidth: 14)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }.padding(.horizontal)

            HStack {
                Button {
                    webView.makeCoordinator().goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .font(.title3)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button {
                    webView.makeCoordinator().goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .font(.title3)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button {
                    webView.makeCoordinator().goHome()
                } label: {
                    Image(systemName: "house.fill")
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .font(.title3)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
    }

    private func loadURL() {
        webView.webView.load(URLRequest(url: URL(string: urlString)!))
    }

}

#Preview {
    BrowserView(urlString: "https://embrace.io")
}
