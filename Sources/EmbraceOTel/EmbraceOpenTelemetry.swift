//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import EmbraceCommon

/*
 TODO: This file, the protocol and implementation was created for testing purposes.
 Prior to merge this PR (or afterwards) this will be unified with austin API updates.
 When that happens:
 - Delete this file
 - Go to `URLSessionCaptureService` and modify the `init` to be compliant with the protocol that
 `EmbraceOTel` implements.
*/
public protocol EmbraceOpenTelemetry {
    func buildSpan(name: String,
                   type: SpanType,
                   attributes: [String: String]) -> SpanBuilder
}

extension EmbraceOTel: EmbraceOpenTelemetry { }
