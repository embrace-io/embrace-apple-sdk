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
            let wwdcdata = try await fetchController.fetchWWDCData()
            status = .success
        } catch {
            status = .failed(error: error)
        }
    }
}
