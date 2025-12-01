//
//  ChannelsScreen.swift
//  tvosTestApp
//
//

import SwiftUI
import AVKit

struct ChannelsScreen: View {
    @StateObject private var viewModel = ChannelsScreenViewModel(fetchController: FetchController())
    @StateObject var playerManager = PlayerManager()

    @State var thumbnails = [String: CGImage]()
    @FocusState var focusedSession: WWDCSession?

    private var currentSelected: WWDCSession? {
        focusedSession ?? viewModel.selectedSession
    }
    
    var body: some View {
        switch viewModel.status {
            case .success:
            Text("\(currentSelected?.title ?? "")")
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 100)), count: 3)) {
                    ForEach(viewModel.sessionsFor(year: 2018), id: \.id) { session in
                        Button {
                            viewModel.userSelectedSession(session)
                        } label: {
                            ChannelThumbnailView(thumbnail: viewModel.thumbnailFor(session))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(.embraceSilver, lineWidth: currentSelected == session ? 4:0)
                                )
                        }
                        .buttonStyle(.borderless)
                        .clipShape(.rect(cornerRadius: 25))
                        .shadow(color: .gray, radius: 2, x: 0, y: 0)
                        .padding(.top, 50)
                        .focused($focusedSession, equals: session)
                        .scaleEffect(currentSelected == session ? 1.2 : 1.0)
                    }
                }
            }
            .fullScreenCover(isPresented: $viewModel.showDetails) {
                ZStack {
                    Color.black.opacity(0.9)
                    ChannelDetailViewScreen(viewModel: viewModel)
                }
                .ignoresSafeArea(.all)
            }
            .fullScreenCover(isPresented: $viewModel.startPlayer) {
                VideoPlayer(player: playerManager.player)
                    .onAppear {
                        guard let streamUrl = viewModel.selectedSession?.media?.streamUrl
                        else {
                            viewModel.startPlayer.toggle()
                            return
                        }
                        playerManager.url = streamUrl
                        playerManager.initializePlayer()
                    }
                    .ignoresSafeArea(.all)
            }
            .onChange(of: viewModel.startPlayer) {
                if viewModel.startPlayer == false {
                    playerManager.player.pause()
                }
            }
        default:
            Text("Loading...")
        }
    }
}

#Preview {
    ChannelsScreen()
        .environment(AppNavigator())
}
