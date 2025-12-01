//
//  PlayerManager.swift
//  tvosTestApp
//
//

import AVKit
import Combine

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
