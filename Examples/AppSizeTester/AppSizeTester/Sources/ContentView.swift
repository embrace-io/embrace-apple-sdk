import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("This app is meant to test the SDK size")
            .onAppear {
                print(NSHomeDirectory())
            }
    }
}
