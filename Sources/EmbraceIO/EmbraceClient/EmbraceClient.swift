
import Foundation

@objc public struct EmbraceClient {

    let appId: String
    let appGroupIdentifier: String?
    let collectorDefinitions: [CollectorDefinition]

    init(appId: String, appGroupIdentifier: String? = nil, collectors: [CollectorDefinition] = .default) {
        self.appId = appId
        self.appGroupIdentifier = appGroupIdentifier
        self.collectorDefinitions = collectors
    }
}
