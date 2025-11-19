//
//  ChannelsScreen.swift
//  tvosTestApp
//
//

import SwiftUI

struct ChannelsScreen: View {
    @StateObject private var viewModel = ChannelsScreenViewModel(fetchController: FetchController())

    var body: some View {
        Text("Channels!")
    }
}
