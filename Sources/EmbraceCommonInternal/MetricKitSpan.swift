//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import MetricKit

/// Represents a MetricKit signpost interval for SDK performance monitoring
/// Signposts are automatically collected by MetricKit and included in MXMetricPayload
@available(iOS 13.0, *)
public class EmbraceMetricKitSpan {

    // MARK: - Public

    /// Begins a signpost interval
    /// - Parameter name: The signpost name (will appear in MXMetricPayload as signpostMetrics.EmbraceSDK.{name})
    /// - Returns: EmbraceMetricKitSpan object - call .end() when the operation completes
    public static func begin(name: StaticString, force: Bool = false) -> EmbraceMetricKitSpan {
        let logged = force || enabled
        if logged {
            mxSignpost(.begin, log: Self.log, name: name)
        }
        return EmbraceMetricKitSpan(name: name, logged: logged)
    }

    /// Ends the signpost interval
    public func end() {
        guard logged && hasEnded.compareExchange(expected: false, desired: true) else {
            return
        }
        mxSignpost(.end, log: Self.log, name: name)
    }

    // MARK: - Private

    /// The OSLog object for EmbraceSDK signposts
    /// Created using MXMetricManager.makeLogHandle to ensure MetricKit tracks these signposts
    private static let log: OSLog = MXMetricManager.makeLogHandle(category: "EmbraceSDK")
    @_spi(EmbraceSDK)
    public static func bootstrap(enabled: Bool) {
        #if DEBUG  // we will remove this later, We just need to collect data for now.
            _enabled.store(true)
        #else
            _enabled.store(enabled)
        #endif
    }
    private static var _enabled: EmbraceAtomic<Bool> = false
    private static var enabled: Bool {
        _enabled.load()
    }

    private let name: StaticString
    private let logged: Bool
    private let hasEnded = EmbraceAtomic<Bool>(false)

    private init(name: StaticString, logged: Bool) {
        self.name = name
        self.logged = logged
    }

    deinit {
        end()
    }
}
