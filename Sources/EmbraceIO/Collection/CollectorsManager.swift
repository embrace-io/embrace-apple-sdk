//
//  File.swift
//  
//
//  Created by Fernando Draghi on 22/09/2023.
//

import Foundation
import EmbraceCommon

final class CollectorsManager {
    let collectors: [Collector]

    init(collectors: [Collector]) {

        // ensure only one instance per collector type
        var map: [String: Bool] = [:]
        var array: [Collector] = []

        for collector in collectors {
            let typeName = String(describing: type(of: collector))
            guard map[typeName] == nil else {
                print("Found duplicated collector of type \(typeName)!")
                continue
            }

            map[typeName] = true
            array.append(collector)
        }

        self.collectors = array
    }

    func start() {
        for collector in collectors {
            if let installedCollector = collector as? InstalledCollector {
                installedCollector.install()
            }

            collector.start()
        }
    }

    func stop() {
        for collector in collectors {
            collector.stop()
        }
    }
}
