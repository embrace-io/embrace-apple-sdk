//
//  ChannelThumbnailView.swift
//  tvosTestApp
//
//

import SwiftUI

struct ChannelThumbnailView: View {
    var thumbnail: ChannelThumbnail
    
    private var fallbackImage: CGImage {
        UIImage(systemName: "exclamationmark.triangle")!.cgImage!
    }
    
    private var usingPlaceholder: Bool {
        thumbnail.isPlaceholder
    }
    
    private var image: CGImage {
        return thumbnail.image ?? fallbackImage
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.embraceLead)
            Image(decorative: image, scale: 1.0)
                .renderingMode(usingPlaceholder ? .template : .original)
                .resizable()
                .scaledToFit()
                .padding(usingPlaceholder ? 90 : -20)
                .colorMultiply(usingPlaceholder ? .embraceSilver : .white)
            
        }
        .frame(width: 480, height: 240)
    }
    
    
}


#Preview {
    ChannelThumbnailView(thumbnail: .init(image: nil, isPlaceholder: true))
}
