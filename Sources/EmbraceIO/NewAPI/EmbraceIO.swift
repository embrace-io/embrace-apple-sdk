//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import Foundation

final public class EmbraceIO: Sendable {

    public static let shared = EmbraceIO()

    public let isAvailable: Bool

    @discardableResult
    public func start() -> Bool {
        do {
            try Embrace.client?.start()
            return true
        } catch {
            failure("init error: \(error)")
            return false
        }
    }

    nonisolated(unsafe) private let _client: Embrace?
    private init() {
        do {
            self._client = try Embrace.setup(
                options: Embrace.Options(
                    appId: Self.appID
                )
            )
            self.isAvailable = self._client != nil
        } catch {
            self._client = nil
            self.isAvailable = false
            failure("init error: \(error)")
        }
    }
}

extension EmbraceIO {

    private func failure(_ msg: String) {
        print("[EmbraceIO] \(msg)")
    }

    private static let appID: String = {
        Bundle.main.infoDictionary?["EMBApplicationId"] as? String ?? ""
    }()

    private func expectClient() -> Embrace? {
        guard let client = _client else {
            failure("client is nil!")
            return nil
        }
        return client
    }
}

// MARK: - Log

extension EmbraceIO {

    public func log(
        _ message: String,
        attributes: @autoclosure () -> [AttributeKey: AttributeValueType]
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
