//
//  ChannelsScreenViewModelStatus.swift
//  tvosTestApp
//
//

import Foundation

enum ChannelsScreenViewModelStatus: Equatable {
    static func == (lhs: ChannelsScreenViewModelStatus, rhs: ChannelsScreenViewModelStatus) -> Bool {
        switch (lhs, rhs) {
        case (let .failed(lhsError), let .failed(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.success, .success), (.notStarted, .notStarted), (.fetching, .fetching):
            return true
        default:
            return false
        }
    }

    case notStarted
    case fetching
    case success
    case failed(error: Error)
}
