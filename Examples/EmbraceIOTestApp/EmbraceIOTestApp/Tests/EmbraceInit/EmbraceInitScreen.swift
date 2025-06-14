//
//  EmbraceInitScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceIO
import EmbraceCrash
import EmbraceObjCUtilsInternal
import OpenTelemetrySdk

struct EmbraceInitScreen: View {
    @Environment(DataCollector.self) private var dataCollector
    @State private var viewModel: EmbraceInitScreenViewModel = EmbraceInitScreenViewModel()

    var body: some View {
        VStack {
            Form {
                Toggle(isOn: $viewModel.simulateEmbraceAPI) {
                    Text("Simulate Embrace API")
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(.embraceSteel)
                }
                .tint(.embracePurple)
                Toggle(isOn: $viewModel.forceColdStart) {
                    Text("Force Cold Start")
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(.embraceSteel)
                }
                .tint(.embracePurple)
                .accessibilityIdentifier("ForceColdStartToggle")
                ForEach($viewModel.formFields, id:\.name) { $section in
                    Section {
                        ForEach($section.items, id:\.name) { $item in
                            TextField(item.name,
                                      text: $item.value)
                            .font(.embraceFont(size: 18))
                            .foregroundStyle(viewModel.formDisabled ? .gray : .embraceSilver)
                            .disabled(viewModel.formDisabled)
                        }
                    } header: {
                        Text(section.name)
                            .textCase(nil)
                            .font(.embraceFont(size: 15))
                    }
                    .opacity(viewModel.simulateEmbraceAPI ? 0.5 : 1.0)
                    .disabled(viewModel.simulateEmbraceAPI)
                }
            }
            .disabled(viewModel.formDisabled)
            EmbraceLargeButton(text: viewModel.embraceHasInitialized ? "EmbraceIO has started!" : "Start EmbraceIO",
                               enabled: !viewModel.formDisabled,
                               buttonAction: startEmbrace)
            .disabled(viewModel.formDisabled)
            .padding()
            .padding(.bottom, 60)
            .accessibilityIdentifier("EmbraceInitButton")
        }
    }
}

#Preview {
    let dataCollector = DataCollector()
    return NavigationView {
        EmbraceInitScreen()
            .environment(dataCollector)
    }
}

private extension EmbraceInitScreen {
    func startEmbrace() {
        if viewModel.forceColdStart {
            UserDefaults.standard.setValue(nil, forKey: "emb.buildUUID")
        }
        self.dataCollector.networkSpy?.simulateEmbraceAPI = viewModel.simulateEmbraceAPI
        do {
            viewModel.showProgressview = true
            let services = CaptureServiceBuilder()
                .add(.view(options: ViewCaptureService.Options(instrumentVisibility: true,
                                                               instrumentFirstRender: true)))

                .addDefaults()
                .build()
            try Embrace
                .setup(options:
                        .init(appId: viewModel.appId,
                              endpoints: .init(
                                baseURL: viewModel.baseURL,
                                configBaseURL: viewModel.configBaseURL),
                              captureServices: services,
                              crashReporter: EmbraceCrashReporter(),
                              export: .init(spanExporter: dataCollector.spanExporter, logExporter: dataCollector.logExporter))
                ).start()
            viewModel.showProgressview = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("UIApplicationDidFinishLaunchingNotification"), object: nil)
            }
        } catch let e {
            viewModel.showProgressview = false
            print("Error initializing Embrace: \(e)")
        }
    }
}
