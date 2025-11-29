//
//  ChannelsScreenViewModel.swift
//  tvosTestApp
//
//

import Combine
import Foundation
import AVKit
import SwiftUI

@MainActor
class ChannelsScreenViewModel: ObservableObject {
    @Published private(set) var status: ChannelsScreenViewModelStatus = .notStarted
    private var wwdcData: WWDCData? = nil
    private let fetchController: FetchController
    @Published private(set) var thumbnails: [Int: [String: CGImage]] = [:]
    private var sessionWithUnavailableThumbnails: [Int: [String]] = [:]
    @Published var showDetails: Bool = false
    private(set) var selectedSession: WWDCSession? = nil
    
    init(fetchController: FetchController) {
        self.fetchController = fetchController
        
        Task {
            await fetchChannels()
        }
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
    
    func userSelectedSession(_ session: WWDCSession) {
        selectedSession = session
        withAnimation {
            showDetails.toggle()
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
    
    func thumbnailFor(_ session: WWDCSession) -> ChannelThumbnail {
        guard let image = thumbnails[session.year]?[session.id] else {
            let placeholder = UIImage(systemName: placeholderSystemImage(for: session))?.cgImage
            return .init(image: placeholder, isPlaceholder: true)
        }
        
        return .init(image: image, isPlaceholder: false)
    }
    
    private func placeholderSystemImage(for session: WWDCSession) -> String {
        if sessionWithUnavailableThumbnails[session.year]?.contains(session.id) ?? false {
            return "xmark.icloud"
        }
        
        return "hourglass"
    }
    
    private func fetchChannels() async {
        status = .fetching
        
        do {
            wwdcData = try await fetchController.fetchWWDCData()
            await loadSessionThumbnails(for: 2018)
            status = .success
        } catch {
            status = .failed(error: error)
        }
    }
    
    private func loadSessionThumbnails(for year: Int) async {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 7
        
        sessionsFor(year: year).forEach { session in
            guard
                let media = session.media,
                let streaUrl = media.streamUrl,
                let url = URL(string: streaUrl)
            else { return }
            
            let operation = BlockOperation {
                let semaphore = DispatchSemaphore(value: 0)
                let asset = AVURLAsset(url: url)
                AVAssetImageGenerator(asset: asset).generateCGImageAsynchronously(for: .init(seconds: 360, preferredTimescale: 60)) { image, _, _ in
                    semaphore.signal()
                    DispatchQueue.main.async {
                        self.thumbnails[year, default:[:]][session.id] = image
                        if image == nil {
                            self.sessionWithUnavailableThumbnails[year, default: []].append(session.id)
                        }
                    }
                }
                semaphore.wait()
            }
            queue.addOperation(operation)
        }
    }
}

