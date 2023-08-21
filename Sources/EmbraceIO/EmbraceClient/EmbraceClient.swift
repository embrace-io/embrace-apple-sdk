import Foundation

@objc public class EmbraceClient: NSObject {

    let appId: String
    let appGroupIdentifier: String?
    let collectorDefinitions: [CollectorDefinition]

    init(appId: String, appGroupIdentifier: String? = nil, collectors: [CollectorDefinition] = .default) {
        self.appId = appId
        self.appGroupIdentifier = appGroupIdentifier
        self.collectorDefinitions = collectors
    }
}
