//
//  ChannelsScreenDataModel.swift
//  tvosTestApp
//
//

import SwiftUI

enum ChannelsScreenDataModel: Int, CaseIterable {
    case details
    case player

    var identifier: String {
        switch self {
        case .details: "channelsExperienceDetailsScreen"
        case .player: "channelsExperiencePlayerScreen"
        }
    }
}
