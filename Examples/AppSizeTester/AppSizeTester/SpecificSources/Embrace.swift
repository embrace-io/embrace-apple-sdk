import Foundation
import EmbraceIO

class EmbraceIntegration {
    static func initialize() {
        try? Embrace.setup(options: .init(appId: "-----")).start()
    }
}