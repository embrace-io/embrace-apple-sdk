//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

typealias BirdsEyeViewAttributes = [String: String]

protocol BirdsEyeViewProvider {
    func provide(_ time: Date) -> BirdsEyeViewAttributes?
}

class BirdsEyeView {
    
    let providers: [BirdsEyeViewProvider]
    
    init() {
        providers = [
            MemoryProvider(),
            TaskRoleProvider(),
            ApplicationProvider(),
            ResourceUsageProvider()
        ]
    }
    
    func beat(at time: Date) {
        guard let client = Embrace.client else {
            return
        }
        
        var attributes: BirdsEyeViewAttributes = [:]
        for provider in providers {
            if let atts = provider.provide(time) {
                attributes.merge(atts) { newKeys, _ in newKeys }
            }
        }
        
        print("[BEV] - ")
        attributes.forEach { key, value in
            print("[BEV] \(key) = \(value)")
        }

        client.recordCompletedSpan(
            name: "emb-birds.eye.view",
            type: .performance,
            parent: nil,
            startTime: time,
            endTime: time,
            attributes: attributes,
            events: [],
            errorCode: nil
        )
    }
}




