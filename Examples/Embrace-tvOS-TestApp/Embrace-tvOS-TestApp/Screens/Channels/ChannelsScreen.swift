//
//  ChannelsScreen.swift
//  tvosTestApp
//
//

import SwiftUI

//
import AVKit
import Combine
//


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

class PlayerManager: ObservableObject {
  @Published var player = AVPlayer()
  private var playerItem: AVPlayerItem?
  private var cancellables = Set<AnyCancellable>()
    var url: String = "" {
        didSet {
            initializePlayer()
        }
    }
    
  func initializePlayer() {
    // Replace with your own URL
    guard let sourceURL = URL(string: url) else {
      print("Invalid URL provided.")
      return
    }

    playerItem = AVPlayerItem(url: sourceURL)
    guard let item = playerItem else { return }

    // Watch for buffer issues
    item.publisher(for: \.isPlaybackBufferEmpty)
      .sink { bufferEmpty in
        if bufferEmpty {
          print("Buffer is empty. Expect a hiccup on screen.")
        }
      }
      .store(in: &cancellables)

    // Keep an eye on playback rate
    player.publisher(for: \.rate)
      .sink { rate in
        print("Playback rate: \(rate)")
      }
      .store(in: &cancellables)

    // Observe overall status
    item.publisher(for: \.status)
      .sink { status in
        switch status {
        case .readyToPlay:
            self.player.play()
        case .failed:
          // This can happen if the stream is invalid or the URL is blocked
          print("Something went wrong with playback.")
        default:
          // rawValue helps you see the numeric representation (0, 1, or 2)
          print("Status changed: \(status.rawValue)")
        }
      }
      .store(in: &cancellables)

    // Optionally track if playback stalls (network dropout, etc.)
    NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: item)
      .sink { _ in
        print("Playback stalled. Possibly a slow connection.")
      }
      .store(in: &cancellables)

    player.replaceCurrentItem(with: item)
  }

  // Basic control functions
  func playVideo() {
    player.play()
  }

  func pauseVideo() {
    player.pause()
  }
}
