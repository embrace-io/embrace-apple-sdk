//
//  ChannelDetailViewScreen.swift
//  tvosTestApp
//
//

import EmbraceMacros
import SwiftUI

@EmbraceTrace
struct ChannelDetailViewScreen: View {
    let viewModel: ChannelsScreenViewModel

    private var fallbackImage: CGImage {
        UIImage(systemName: "xmark.icloud")!.cgImage!
    }

    private var image: CGImage {
        guard let selectedSession = viewModel.selectedSession else {
            return fallbackImage
        }

        return viewModel.thumbnailFor(selectedSession).image ?? fallbackImage
    }

    private var usingPlaceholder: Bool {
        guard let selectedSession = viewModel.selectedSession else {
            return true
        }

        return viewModel.thumbnailFor(selectedSession).isPlaceholder
    }

    var body: some View {
        VStack {
            HStack {
                VStack {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .renderingMode(usingPlaceholder ? .template : .original)
                        .colorMultiply(usingPlaceholder ? .embraceSilver : .white)
                        .scaledToFit()
                        .frame(width: 480, height: 240)
                        .padding(.bottom, 40)
                    Text(viewModel.selectedSession?.title ?? "")
                        .padding(.bottom, 40)
                }
                Text(viewModel.selectedSession?.description ?? "")
                    .frame(width: 600)
            }
            .padding(.bottom, 40)
            Button {
                viewModel.playVideo()
            } label: {
                Image(systemName: "play.fill")
            }
        }
    }
}

#Preview {
    let session = try! JSONDecoder().decode(WWDCSession.self, from: WWDCSession.mockData)
    let viewModel = ChannelsScreenViewModel(fetchController: FetchController())
    viewModel.userSelectedSession(session)
    return ChannelDetailViewScreen(viewModel: viewModel)
}
