//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

typealias BirdsEyeViewAttributes = [String: String]

protocol BirdsEyeViewProvider {
    func provide(_ time: Date) -> BirdsEyeViewAttributes?
    func stream() -> AsyncStream<[String]>?
}

class BirdsEyeView {
    
    let providers: [BirdsEyeViewProvider]
    var streamTask: Task<Void, Never>? = nil
    
    init() {
        providers = [
            MemoryProvider(),
            TaskRoleProvider(),
            ApplicationProvider().register(),
            ResourceUsageProvider()
        ]
        
        streamTask = Task {
            for await changes in mergeStream(providers) {
                _enqueueBeat(changes)
            }
        }
    }
    
    deinit {
        streamTask?.cancel()
    }
    
    func mergeStream(_ providers: [BirdsEyeViewProvider]) -> AsyncStream<[String]> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            for p in providers {
                if let stream = p.stream() {
                    Task {
                        for await changes in stream {
                            continuation.yield(changes)
                        }
                    }
                }
            }
        }
    }
    
    func _enqueueBeat(_ changes: [String]) {
        beat(at: Date(), type: "push[\(changes.joined(separator: ","))]")
    }
    
    func beat(at time: Date, type: String = "heartbeat") {
        guard let client = Embrace.client else {
            return
        }
        
        var attributes: BirdsEyeViewAttributes = [:]
        for provider in providers {
            if let atts = provider.provide(time) {
                attributes.merge(atts) { newKeys, _ in newKeys }
            }
        }
        
        print("[BEV]")
        print("[BEV] - \(type) - ")
        attributes.keys.sorted().forEach { key in
            print("[BEV] \(key) = \(attributes[key]!)")
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




