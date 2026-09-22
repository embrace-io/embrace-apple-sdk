//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import OpenTelemetryApi
import SwiftUI

struct OpenTelemetryView: View {
    @State private var name: String = "EmbraceOpenTelemetry"
    @State private var version = "6.1.1"
    @State private var tracer: Tracer? {
        didSet {
            goNext = true
        }
    }
    @State private var selectedProviderSDK: TracerProviderSDK = .embrace
    @State private var goNext: Bool = false
    private let labelWidth: CGFloat = 70.0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Method", selection: $selectedProviderSDK) {
                    ForEach(TracerProviderSDK.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                VStack {
                    HStack {
                        Text("name: ")
                            .frame(width: labelWidth, alignment: .leading)
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    if selectedProviderSDK == .otel {
                        HStack {
                            Text("Version:")
                                .frame(width: labelWidth, alignment: .leading)
                            TextField("", text: $version)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }.padding(.horizontal)
                Spacer()
                Button {
                    getOpenTelemetryTracer()
                } label: {
                    Text("Get \(selectedProviderSDK.rawValue) Tracer")
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .bold()
                }
                .background(selectedProviderSDK == .embrace ? Color.embraceYellow : .accentColor)
                .foregroundColor(selectedProviderSDK == .embrace ? .black : .white)
                .cornerRadius(6.0)
                .padding()
            }.navigationTitle("Create a Tracer")
        }.navigationDestination(isPresented: $goNext) {
            if let tracer = tracer {
                CreateSpanView(tracer: tracer)
            } else {
                EmptyView()
            }
        }
    }
}

extension OpenTelemetryView {
    fileprivate func getOpenTelemetryTracer() {
        do {
            tracer =
                switch selectedProviderSDK {
                case .embrace:
                    try getEmbraceTracer()
                case .otel:
                    try getOTelSDKTracer()
                }

        } catch let exception {
            print(exception.localizedDescription)
        }
    }

    /// Spans from this tracer are captured by Embrace: it comes from the provider backing the
    /// Embrace pipeline, so every span reaches the Embrace session as well as any exporters
    /// configured through `EmbraceIO.OTelOptions`.
    fileprivate func getEmbraceTracer() throws -> Tracer {
        guard !name.isEmpty else { throw CreateTracerError.nameCannotBeEmpty }
        guard let tracer = EmbraceIO.shared.tracer(instrumentationName: name) else {
            throw CreateTracerError.embraceTracerUnavailable
        }
        return tracer
    }

    /// Spans from this tracer are only captured by Embrace if the app enabled
    /// `registersGlobalProviders` in its `EmbraceIO.OTelOptions`. Otherwise the process-wide
    /// provider is whatever the app registered, defaulting to a no-op provider that drops them.
    fileprivate func getOTelSDKTracer() throws -> Tracer {
        guard !name.isEmpty else { throw CreateTracerError.nameCannotBeEmpty }
        guard !version.isEmpty else { throw CreateTracerError.versionCannotBeEmpty }
        guard isValidSemver(version: version) else { throw CreateTracerError.versionIsNotSemver }
        return OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: name,
            instrumentationVersion: version
        )
    }

    fileprivate func isValidSemver(version: String) -> Bool {
        // swiftlint:disable line_length
        let regex = #"""
            ^(\d+)\.(\d+)\.(\d+)(?:-((?:\d+|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:\d+|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
            """#
        // swiftlint:enable line_length
        let result = version.range(of: regex, options: .regularExpression)
        return result != nil
    }
}

extension OpenTelemetryView {
    fileprivate enum TracerProviderSDK: String, CaseIterable, Identifiable {
        case embrace = "Embrace"
        case otel = "OpenTelemetry"

        var id: String { self.rawValue }
    }
}

extension OpenTelemetryView {
    fileprivate enum CreateTracerError: LocalizedError {
        case embraceTracerUnavailable
        case nameCannotBeEmpty
        case versionCannotBeEmpty
        case versionIsNotSemver

        var errorDescription: String? {
            switch self {
            case .embraceTracerUnavailable:
                "No Embrace tracer available; start the SDK with `OTelOptions` before running this"
            case .nameCannotBeEmpty:
                "Name cannot be empty"
            case .versionCannotBeEmpty:
                "Version cannot be empty"
            case .versionIsNotSemver:
                "Version should be in semver format"
            }
        }
    }
}

#Preview {
    NavigationStack {
        OpenTelemetryView()
    }
}
