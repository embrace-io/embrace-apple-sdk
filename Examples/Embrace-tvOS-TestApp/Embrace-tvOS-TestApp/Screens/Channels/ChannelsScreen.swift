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
    
    var body: some View {
        switch viewModel.status {
            case .success:
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 100)), count: 3)) {
                    ForEach(viewModel.sessionsFor(year: 2018), id: \.id) { session in
                        generateThumbnail(for: session)
                            .focusable(true)
                            .padding(.bottom, 50)
                    }
                }
            }
        default:
            Text("Loading...")
        }
//        VStack {
//              // The built-in SwiftUI VideoPlayer
//              VideoPlayer(player: playerManager.player)
//                .frame(height: 500)
//                
//
//              // Basic playback controls
//              HStack {
//                Button("Play") {
//                  playerManager.playVideo()
//                }
//                .padding(.horizontal, 10)
//
//                Button("Pause") {
//                  playerManager.pauseVideo()
//                }
//                .padding(.horizontal, 10)
//              }
//            }
//        .onChange(of: viewModel.status) { oldValue, newValue in
//            guard newValue == .success else { return }
//            guard let year = viewModel.yearsWithAvailableMedia.first else { return }
//            let session = viewModel.sessionsFor(year: 2018)!.first!
//            
//            playerManager.url = session.media!.streamUrl!
//        }
    }
    
    func generateThumbnail(for session: WWDCSession) -> ChannelThumbnailView {
        guard let image = viewModel.thumbnails[2018]?[session.id] else {
            return ChannelThumbnailView(systemName: viewModel.placeholderSystemImage(for: session.id, year: 2018))
        }
        return ChannelThumbnailView(thumbnailImage: image)
    }
}

#Preview {
    ChannelsScreen()
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
          print("Ready to play!")
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
