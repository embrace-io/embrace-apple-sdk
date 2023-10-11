//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import Charts

struct NetworkStressTest: View {

    static let quickURLs = [
        "https://www.example.com",
        "https://www.google.com",
        "https://www.apple.com"

    ]

    @State var inputURL: String = NetworkStressTest.quickURLs.first!
    @State var inputCount: UInt = 20
    @State var didSubmit: Bool = false

    @State var responses: [NetworkResponse] = []

    var body: some View {
        VStack {
            Form {
                List {
                    Section("Quick URLs") {
                        ForEach(NetworkStressTest.quickURLs, id: \.self) { item in
                            Text(item)
                                .foregroundStyle(inputURL == item ? Color.gray : Color.black)
                                .disabled(inputURL == item)
                                .onTapGesture {
                                    inputURL = item
                                }

                        }
                    }
                }

                TextField("URL", text: $inputURL)
                Stepper("^[\(inputCount) Request](inflect: true)",
                        value: $inputCount,
                        in: 1...1000, step: 1)

                Button("Submit") {
                    didSubmit = true
                }

                Section {
                    if !responses.isEmpty {

                        Text("Round Trip Times")
                            .bold()

                        Chart(responses) { r in
                            BarMark(x: .value("idx", r.id), y: .value("rtt", r.rtt))
                        }
                            .chartXAxis(.hidden)
                            .padding(.vertical)
                            .frame(minHeight: 140)

                        Text("Min: ^[\(responses.min(by: { $0.rtt < $1.rtt })!.rtt) second](inflect: true)")
                        Text("Max: ^[\(responses.max(by: { $0.rtt < $1.rtt })!.rtt) second](inflect: true)")
                    } else if didSubmit {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .task(id: didSubmit) {
            guard didSubmit else { return }
            responses = []

            await withTaskGroup(of: NetworkResponse?.self) { group in
                for i in 0..<inputCount {
                    group.addTask {
                        do {
                            if let request = NetworkRequest(string: inputURL, idx: i) {
                                return try await request.execute()
                            } else {
                                return nil
                            }
                        } catch {
                            return nil
                        }
                    }
                }

                self.responses = await group.reduce(into: []) { partialResult, response in
                    if let response { partialResult.append(response) }
                }
            }

            didSubmit = false
        }
        .navigationTitle("Network Stress")

    }
}

#Preview {
    NetworkStressTest()
}
