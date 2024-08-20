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

    @State private var inputURL: String = NetworkStressTest.quickURLs.first!
    @State private var inputCount: UInt = 20
    @State private var didSubmit: Bool = false
    @State private var useNewConcurrency: Bool = false

    @State private var responses: [NetworkResponse] = []

    var body: some View {
        VStack {
            Form {
                Section("Configuration") {
                    Toggle(isOn: $useNewConcurrency) {
                        Text("Use new concurrency?")
                    }
                }
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

                Section {
                    NavigationLink {
                        NetworkRequestBuilderView()
                    } label: {
                        Text("Build complex request")
                    }
                } header: {
                    Text("Other Options")
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

                        Chart(responses) { response in
                            BarMark(x: .value("idx", response.id), y: .value("rtt", response.rtt))
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
            guard didSubmit else {
                return
            }

            responses = []

            if useNewConcurrency {
                await performNewConcurrencyRequests()
                didSubmit = false
            } else {
                performLegacyRequests {
                    didSubmit = false
                }
            }
        }
        .navigationTitle("Network Requests")
    }

    private func performNewConcurrencyRequests() async {
        for index in 0..<inputCount {
            if let request = NetworkRequest(string: inputURL, idx: index),
               let response = await request.execute() {
                responses.append(response)
            }
        }
    }

    private func performLegacyRequests(completion: @escaping () -> Void) {
        let group = DispatchGroup()

        for index in 0..<inputCount {
            group.enter()
            if let request = NetworkRequest(string: inputURL, idx: index) {
                request.execute { response in
                    DispatchQueue.main.async {
                        if let response = response {
                            self.responses.append(response)
                        }
                        group.leave()
                    }
                }
            }        }

        group.notify(queue: .main) {
            completion()
        }
    }
}

#Preview {
    NavigationStack {
        NetworkStressTest()
            .navigationBarTitleDisplayMode(.inline)
    }
}
