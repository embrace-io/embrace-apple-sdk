//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct MemoryPressureSimulatorView: View {
    @State var simulator: MemoryPressureSimulator = .init()

    var body: some View {
        VStack {
            Spacer()
            Text("Memory Used: \(simulator.totalMemoryBytes / 1024 / 1024) MB")
                .font(.title2)
                .bold()
            Spacer()
            VStack {
                Button {
                    !simulator.isSimulating ? simulator.startSimulating() : simulator.stopSimulating()
                } label: {
                    Text(!simulator.isSimulating ? "Start Simulation" : "Stop Simulation")
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .font(.title3)
                        .bold()
                }
                Button {
                    executeMemoryWarning()
                } label: {
                    Text("Manually Trigger Notification")
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .font(.title3)
                        .bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }.navigationTitle("Memory Pressure Simulator")
    }

    private func executeMemoryWarning() {
        UIApplication.shared.perform(Selector(("_performMemoryWarning")))
    }
}

#Preview {
    MemoryPressureSimulatorView()
}
