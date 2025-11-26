//
//  ChannelsScreenViewModel.swift
//  tvosTestApp
//
//

import Combine
import Foundation
import AVKit

@MainActor
class ChannelsScreenViewModel: ObservableObject {
    @Published private(set) var status: ChannelsScreenViewModelStatus = .notStarted
    private var wwdcData: WWDCData? = nil
    private let fetchController: FetchController
    @Published private(set) var thumbnails: [Int: [String: CGImage]] = [:]

    init(fetchController: FetchController) {
        self.fetchController = fetchController
        
        Task {
            await fetchChannels()
        }
    }
    
    private func fetchChannels() async {
        status = .fetching
        
        do {
            wwdcData = try await fetchController.fetchWWDCData()
            await loadSessionThumbnails()
            status = .success
        } catch {
            status = .failed(error: error)
        }
    }
    
    func sessionsFor(year: Int) -> [WWDCSession] {
        guard let wwdcData = wwdcData else { return [] }
        
        let filtered = wwdcData.sessions.filter {
            $0.year == year
        }
        
        let onlyWithAvailableMedia = filtered.filter {
            $0.media?.containsStreamingMedia ?? false
        }
        
        return onlyWithAvailableMedia.sorted { $0.eventContentId < $1.eventContentId }
    }
    
    var availableYears: [Int] {
        let years = Set<Int>(wwdcData?.sessions.map(\.year) ?? [])
        
        return years.sorted()
    }
    
    var yearsWithAvailableMedia: [Int] {
        availableYears.filter {
            sessionsFor(year: $0).count > 0
        }
    }
    
    private func loadSessionThumbnails() async {
        yearsWithAvailableMedia.forEach { year in
            guard year == 2018 else { return }
            sessionsFor(year: year).forEach { session in
                guard
                    let media = session.media,
                    let streaUrl = media.streamUrl,
                    let url = URL(string: streaUrl)
                else { return }
                
                let asset = AVURLAsset(url: url)
                AVAssetImageGenerator(asset: asset).generateCGImageAsynchronously(for: .init(seconds: 360, preferredTimescale: 60)) { image, _, _ in
                    guard let image = image else { return }
                    DispatchQueue.main.async {
                        self.thumbnails[year, default:[:]][session.id] = image
                    }
                }
            }
        }
    }
}
