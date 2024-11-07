//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import EmbraceIO

struct BombView: View {
    @State private var showTooltip: Bool
    @State private var showAddCrashInfo: Bool

    init(
        showTooltip: Bool = false,
        showAddCrashInfo: Bool = false
    ) {
        UITableView.appearance().backgroundColor = .clear
        self.showTooltip = showTooltip
        self.showAddCrashInfo = showAddCrashInfo
    }

    var body: some View {
        VStack {
            List(Bomb.allCases, id: \.self) { option in
                Button(action: {
                    let bomb = option.case
                    try? Embrace.client?.appendCrashInfo(
                        key: "bomb",
                        value: bomb.title
                    )
                    option.case.crash()
                }, label: {
                    VStack {
                        Text(option.case.title)
                    }
                }).listRowBackground(Color.clear)
            }
            .listStyle(PlainListStyle())
            .background(Color.clear)
        }
        .padding()
        .navigationTitle("BombApp")
        .toolbar {
            Button {
                withAnimation(.spring()) {
                    showAddCrashInfo.toggle()
                }
            } label: {
                Image(systemName: "gear")
                    .tint(.primary)
            }.sheet(isPresented: $showAddCrashInfo) {
                NavigationStack {
                    AddCrashInfoView()
                }.presentationDetents([.medium, .large])
            }

            Button(action: {
                withAnimation(.spring()) {
                    showTooltip.toggle()
                }
            }, label: {
                Image(systemName: "info.circle")
                    .tint(.primary)
            })
            .sheet(isPresented: $showTooltip) {
                Text("""
                    Build this app using the **Release** build configuration and install it on a device.

                    Either use **Archive** or **Build** for Profiling and copy the app bundle onto the device.

                    **Debug** build configuration has disabled some compiler optimizations.
                    """)
                .background(.background)
                .foregroundColor(.primary)
                .font(.callout)
                .padding(.horizontal)
                .presentationDetents([.fraction(0.25)])
            }
        }
    }
}

#Preview {
    NavigationStack {
        BombView(showTooltip: false)
    }
}
