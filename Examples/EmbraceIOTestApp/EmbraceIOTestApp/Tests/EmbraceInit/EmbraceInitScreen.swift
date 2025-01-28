//
//  EmbraceInitScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceIO

import OpenTelemetrySdk

struct EmbraceInitScreen: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    @State private var appId: String = "AK5HV"
    @State private var baseURL: String = "http://127.0.0.1:8989/api"
    @State private var devBaseURL: String = "http://127.0.0.1:8989/api"
    @State private var configBaseURL: String = "http://127.0.0.1:8989/api"

    private var embraceHasInitialized: Bool {
        Embrace.client?.started ?? false
    }
    private var formDisabled: Bool {
        showProgressview || embraceHasInitialized
    }
    @State private var showProgressview: Bool = false
    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("AppID", text: $appId)
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(formDisabled ? .gray : .embraceSilver)
                        .disabled(formDisabled)
                } header: {
                    Text("APP ID")
                        .textCase(nil)
                        .font(.embraceFont(size: 15))
                }
                Section {
                    TextField("Base URL", text: $baseURL)
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(formDisabled ? .gray : .embraceSilver)
                        .disabled(formDisabled)
                } header: {
                    Text("API Base URL")
                        .textCase(nil)
                        .font(.embraceFont(size: 15))
                }
                Section {
                    TextField("Dev Base URL", text: $devBaseURL)
                        .font(.embraceFont(size: 18))

                        .foregroundStyle(formDisabled ? .gray : .embraceSilver)
                        .disabled(formDisabled)
                } header: {
                    Text("API Dev Base URL")
                        .textCase(nil)
                        .font(.embraceFont(size: 15))
                }
                Section {
                    TextField("Config Base URL", text: $configBaseURL)
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(formDisabled ? .gray : .embraceSilver)
                        .disabled(formDisabled)
                } header: {
                    Text("Config Base URL")
                        .textCase(nil)
                        .font(.embraceFont(size: 15))
                }
            }
            EmbraceLargeButton(text: embraceHasInitialized ? "EmbraceIO has started!" : "Start EmbraceIO",
                               enabled: !formDisabled,
                               buttonAction: startEmbrace)
                .disabled(formDisabled)
                .padding()
                .padding(.bottom, 60)
                .accessibilityIdentifier("EmbraceInitButton")
        }
    }
}

#Preview {
    NavigationView {
        EmbraceInitScreen()
    }
}

private extension EmbraceInitScreen {
    func startEmbrace() {
        do {
            showProgressview = true
            let services = CaptureServiceBuilder()
                .add(.view(options: ViewCaptureService.Options(instrumentVisibility: true,
                                                               instrumentFirstRender: true)))
                .addDefaults()
                .build()
            try Embrace
                .setup(options:
                        .init(appId: appId,
                              endpoints: .init(
                                baseURL: baseURL,
                                developmentBaseURL: devBaseURL,
                                configBaseURL: configBaseURL),
                              captureServices: services,
                              crashReporter: nil,
                              export: .init(spanExporter: spanExporter))
                ).start()
            showProgressview = false
        } catch let e {
            showProgressview = false
            print("Error initializing Embrace: \(e)")
        }
    }
}
