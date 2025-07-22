//
//  EmbraceInitScreen.swift
//  EmbraceIOTestApp
//
//

import EmbraceCrash
import EmbraceIO
import EmbraceObjCUtilsInternal
import OpenTelemetrySdk
import SwiftUI

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
                Section {
                    EmbraceInitScreenForceStateView(forceInitState: $viewModel.forceInitState)
                } header: {
                    Text("Force Start State")
                        .textCase(nil)
                        .font(.embraceFont(size: 15))
                }
                ForEach($viewModel.formFields, id: \.name) { $section in
                    Section {
                        ForEach($section.items, id: \.name) { $item in
                            TextField(
                                item.name,
                                text: $item.value
                            )
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
            EmbraceLargeButton(
                text: viewModel.embraceHasInitialized ? "EmbraceIO has started!" : "Start EmbraceIO",
                enabled: !viewModel.formDisabled,
                buttonAction: startEmbrace
            )
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

extension EmbraceInitScreen {
    fileprivate func startEmbrace() {
        switch viewModel.forceInitState {
        case .off:
            break
        case .cold:
            UserDefaults.standard.setValue(nil, forKey: "emb.buildUUID")
            UserDefaults.standard.setValue(0, forKey: "emb.bootTime")
        case .warm:
            let oldBuildUUID = UserDefaults.standard.string(forKey: "emb.buildUUID")
            let oldBootTime = UserDefaults.standard.double(forKey: "emb.bootTime")
            let newBuildUUID = EMBDevice.buildUUID?.uuidString
            let newBootTime = EMBDevice.bootTime.doubleValue
            if (oldBuildUUID == nil || oldBootTime == 0) || (oldBuildUUID != newBuildUUID && oldBootTime != newBootTime)
            {
                UserDefaults.standard.setValue(newBuildUUID, forKey: "emb.buildUUID")
                UserDefaults.standard.setValue(newBootTime, forKey: "emb.bootTime")
            }
        }

        self.dataCollector.networkSpy?.simulateEmbraceAPI = viewModel.simulateEmbraceAPI
        do {
            viewModel.showProgressview = true
            let services = CaptureServiceBuilder()
                .add(
                    .view(
                        options: ViewCaptureService.Options(
                            instrumentVisibility: true,
                            instrumentFirstRender: true))
                )

                .addDefaults()
                .build()
            try Embrace
                .setup(
                    options:
                        .init(
                            appId: viewModel.appId,
                            endpoints: .init(
                                baseURL: viewModel.baseURL,
                                configBaseURL: viewModel.configBaseURL),
                            captureServices: services,
                            crashReporter: EmbraceCrashReporter(),
                            export: .init(
                                spanExporter: dataCollector.spanExporter, logExporter: dataCollector.logExporter))
                ).start()
            viewModel.showProgressview = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("UIApplicationDidFinishLaunchingNotification"), object: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                Embrace.client?.buildSpan(name: "app-initialization-sdTextNowSwift.AppHealthInitializer: 0x6000000094a0").startSpan().end(time: Date(timeIntervalSinceNow: 1000))
                Embrace.client?.buildSpan(name: "Test Custom Span").startSpan().end(time: Date(timeIntervalSinceNow: 1000))
                Embrace.client?.buildSpan(name: "Test Custom Span With Brackets <ASDASD>").startSpan().end(time: Date(timeIntervalSinceNow: 1000))
                Embrace.client?.buildSpan(name: "Test Custom Span With Brackets <ASDASD:0x123123>app-initialization-TextNowSwift.AppHealthInitializer: 0x6000000094a0").startSpan().end(time: Date(timeIntervalSinceNow: 1000))
            }
        } catch let e {
            viewModel.showProgressview = false
            print("Error initializing Embrace: \(e)")
        }
    }
}
