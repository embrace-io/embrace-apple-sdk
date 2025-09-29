//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import Foundation

final public class EmbraceIO: Sendable {

    public static let shared = EmbraceIO()

    public let isAvailable: Bool

    public func start() throws {
        try Embrace.client?.start()
    }

    nonisolated(unsafe) private let _client: Embrace?
    private init() {
        self._client = try? Embrace.setup(
            options: Embrace.Options(
                appId: Self.appID
            )
        )
        self.isAvailable = self._client != nil
    }
}

extension EmbraceIO {

    private static let appID: String = {
        Bundle.main.infoDictionary?["EMBApplicationId"] as? String ?? ""
    }()

    private func expectClient() -> Embrace? {
        guard let client = _client else {
            print("[EmbraceIO] client is nil!")
            return nil
        }
        return client
    }
}

// MARK: - Log

extension EmbraceIO {

    public func log(
        _ message: String,
        attributes: @autoclosure () -> [AttributeKey: AttributeValue]
    ) {
        guard let client = expectClient() else {
            return
        }

        client.log(
            message,
            severity: .info,
            type: .message,
            timestamp: Date(),
            attributes: attributes().asInternalAttributes(),
            stackTraceBehavior: .notIncluded
        )
    }
}

// MARK: - Span

extension EmbraceIO {

}
