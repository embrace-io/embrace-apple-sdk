//
//  ChannelThumbnailView.swift
//  tvosTestApp
//
//

import SwiftUI

struct ChannelThumbnailView: View {
    var thumbnailImage: CGImage?
    var systemName: String?
    
    init(thumbnailImage: CGImage) {
        self.thumbnailImage = thumbnailImage
    }
    
    init(systemName: String) {
        self.systemName = systemName
    }

    init () {
        self.systemName = nil
        self.thumbnailImage = nil
    }

    private var image: CGImage {
        if let thumbnailImage = thumbnailImage {
            return thumbnailImage
        }
        
        if let systemName = systemName {
            return (UIImage(systemName: systemName)?.cgImage ?? fallbackImage)
        }
    
        return fallbackImage
    }
    
    private var fallbackImage: CGImage {
        UIImage(systemName: "exclamationmark.triangle")!.cgImage!
    }
    
    private var usingSystemImage: Bool {
        thumbnailImage == nil
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.embraceLead)
            Image(decorative: image, scale: 1.0)
                .renderingMode(usingSystemImage ? .template : .original)
                .resizable()
                .scaledToFit()
                .padding(usingSystemImage ? 90 : -20)
                .colorMultiply(usingSystemImage ? .embraceSilver : .white)
        }
        .frame(width: 480, height: 240)
        .clipShape(.rect(cornerRadius: 25))
        .shadow(color: .gray, radius: 2, x: 0, y: 0)
    }
}


#Preview {
    ChannelThumbnailView()
}
