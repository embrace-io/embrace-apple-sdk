//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceCore
import Foundation

final public class EmbraceIO: Sendable {

    public static let shared = EmbraceIO()

    public let isAvailable: Bool

    nonisolated(unsafe) private let _client: Embrace?
    private init() {
        do {
            self._client = try Embrace.setup(
                options: Embrace.Options(
                    appId: Self.appID
                )
            ).start()
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
        Bundle.main.infoDictionary?["EMBApplicationId"] as? String ?? "12345"
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
        _ level: LogSeverity = .info,
        _ message: String,
        timestamp: NanosecondClock = .current,
        attributes: @autoclosure () -> [AttributeKey: AttributeValueType]? = nil
    ) {
        expectClient()?.log(
            message,
            severity: level,
            type: .message,
            timestamp: timestamp.date,
            attributes: attributes()?.asInternalAttributes() ?? [:],
            stackTraceBehavior: .notIncluded
        )
    }
}

// MARK: - Span

extension EmbraceIO {

}
