//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import EmbraceIO
import OpenTelemetryApi

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

private extension OpenTelemetryView {
    func getOpenTelemetryTracer() {
        do {
            tracer = switch selectedProviderSDK {
            case .embrace:
                try getEmbraceTracer()
            case .otel:
                try getOTelSDKTracer()
            }

        } catch let exception {
            print(exception.localizedDescription)
        }
    }

    func getEmbraceTracer() throws -> Tracer {
        guard let embrace = Embrace.client else { throw CreateTracerError.embraceClientDoesNotExist }
        guard !name.isEmpty else { throw CreateTracerError.nameCannotBeEmpty }
        return embrace.tracer(instrumentationName: name)
    }

    func getOTelSDKTracer() throws -> Tracer {
        guard !name.isEmpty else { throw CreateTracerError.nameCannotBeEmpty }
        guard !version.isEmpty else { throw CreateTracerError.versionCannotBeEmpty }
        guard isValidSemver(version: version) else { throw CreateTracerError.versionIsNotSemver }
        return OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: name,
            instrumentationVersion: version
        )
    }

    func isValidSemver(version: String) -> Bool {
        // swiftlint:disable line_length
        let regex = #"""
        ^(\d+)\.(\d+)\.(\d+)(?:-((?:\d+|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:\d+|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
        """#
        // swiftlint:enable line_length
        let result = version.range(of: regex, options: .regularExpression)
        return result != nil
    }
}

private extension OpenTelemetryView {
    enum TracerProviderSDK: String, CaseIterable, Identifiable {
        case embrace = "Embrace"
        case otel = "OpenTelemetry"

        var id: String { self.rawValue }
    }
}

private extension OpenTelemetryView {
    enum CreateTracerError: LocalizedError {
        case embraceClientDoesNotExist
        case nameCannotBeEmpty
        case versionCannotBeEmpty
        case versionIsNotSemver

        var errorDescription: String? {
            switch self {
            case .embraceClientDoesNotExist:
                "Embrace.client returns `nil`; initialize Embrace before running this"
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
