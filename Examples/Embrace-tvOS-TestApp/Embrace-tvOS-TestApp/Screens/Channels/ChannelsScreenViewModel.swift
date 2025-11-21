//
//  ChannelsScreenViewModel.swift
//  tvosTestApp
//
//

import Combine

@MainActor
class ChannelsScreenViewModel: ObservableObject {
    enum Status {
        case notStarted
        case fetching
        case success
        case failed(error: Error)
    }
    
    @Published private(set) var status: Status = .notStarted
    private var wwdcData: WWDCData? = nil
    private let fetchController: FetchController
    
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
            status = .success
        } catch {
            status = .failed(error: error)
        }
    }
    
    func sessionsFor(year: Int) -> [WWDCSession]? {
        guard let wwdcData = wwdcData else { return nil }
        
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
            sessionsFor(year: $0)?.count ?? 0 > 0
        }
    }
}
