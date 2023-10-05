//
//  File.swift
//  
//
//  Created by Fernando Draghi on 22/09/2023.
//

import Foundation

final class EmbraceCollectorsManager {
    static var installCollectors: [InstalledCollector.Type] = [
        TapsCollector.self
    ]

    func initializeCollectors(with options: EmbraceOptions) {
        let platform = options.platform

        EmbraceCollectorsManager.installCollectors.forEach { type in
            guard type.platformAvailability.contains(platform) else { return }

            let collector = type.init()
            collector.install()
            collector.start()
        }
    }
}
