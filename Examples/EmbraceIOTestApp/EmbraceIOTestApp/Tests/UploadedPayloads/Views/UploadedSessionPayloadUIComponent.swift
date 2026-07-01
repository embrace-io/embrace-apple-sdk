//
//  UploadedSessionPayloadUIComponent.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct UploadedSessionPayloadUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector
    @Environment(\.scenePhase) var scenePhase
    @State var dataModel: any TestScreenDataModel
    @State private var viewModel: UploadedSessionPayloadTestViewModel

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        self.viewModel = .init(dataModel: dataModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Section("User Info") {
                    UploadedSessionPayloadTestUserInfoView(
                        identifier: $viewModel.userInfoIdentifier
                    ) {
                        viewModel.clearAllUserInfo()
                    }
                    .padding(.top, 5)
                }
                Section("Personas") {
                    UploadedSessionPayloadTestPersonasView { persona, lifespan in
                        viewModel.addedNewPersona(persona, lifespan: lifespan)
                    } removeAllAction: {
                        viewModel.removeAllPersonas()
                    }
                }
                .padding([.top, .bottom], 8)
                Section("Current Session:") {
                    Text("\(viewModel.currentSessionId ?? "-")")
                        .font(.embraceFont(size: 12))
                        .padding(.top, 2)
                        .padding(.bottom, 5)
                        .padding(.leading, 10)
                }
                Section("Last Session:") {
                    Text("\(viewModel.lastSessionId ?? "-")")
                        .font(.embraceFont(size: 12))
                        .padding(.top, 2)
                        .padding(.bottom, 5)
                        .padding(.leading, 10)
                }
                Text(
                    "Manually background the app and reopen in order to kick off the session post process. Each posted session part appears as its own entry; after at least one part has been posted, a picker will appear with the last posted part selected by default."
                )
                .foregroundStyle(.embraceSteel)
                .font(.embraceFont(size: 12))
                .padding([.top, .bottom], 5)
                Section("Posted Session Part To Test:") {
                    Picker("Posted Session Part", selection: $viewModel.selectedPartId) {
                        ForEach(viewModel.postedParts, id: \.self) { partId in
                            Text(partId)
                                .tag(partId)
                                .font(.embraceFont(size: 12))
                                .foregroundColor(.embracePurple)
                        }
                    }
                }
                .opacity(viewModel.postedParts.count == 0 ? 0.0 : 1.0)
                TestScreenButtonView(viewModel: viewModel)
                    .disabled(viewModel.testButtonDisabled)
                    .onAppear {
                        // `dataCollector` is only available here (not at init), so wire it up and
                        // refresh now — otherwise sessions posted before this page opened stay
                        // invisible until the next payload arrives. Register observers here too, so
                        // they bind to the rendered view-model instance.
                        viewModel.dataCollector = dataCollector
                        viewModel.startObserving()
                        viewModel.refresh()
                    }
                    .padding(.bottom, 140)
            }
        }
        // Non-elidable dependency on the base observation registrar: subclass-only state changes
        // (picker list, current/previous session) bump `viewRefreshToken`, forcing a re-render.
        // See `UIComponentViewModelBase.viewRefreshToken`.
        .onChange(of: viewModel.viewRefreshToken) {}
        .onChange(of: scenePhase) {
            viewModel.refresh()
        }
    }
}

#Preview {
    let dataCollector = DataCollector()
    return UploadedSessionPayloadUIComponent(dataModel: UploadedPayloadsTestsDataModel.sessionPayload)
        .environment(dataCollector)
}
