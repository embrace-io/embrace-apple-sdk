//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    
import EmbraceOTel

protocol EmbraceOTelHandlingProvider {
    var otelHandler: EmbraceOpenTelemetry? { get }
}

/// The intention of this class is to provide the current handler of EmbraceOTel to the data collectors
/// so that they would have somewhere to send the collected data..
/// By default, this would be the current Embrace instance.
/// Be aware that more than likely this will change in the future.
class EmbraceOtelProvider: EmbraceOTelHandlingProvider {
    public var otelHandler: EmbraceOpenTelemetry? {
        Embrace.client
    }
}
