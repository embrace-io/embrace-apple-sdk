//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

public protocol EmbraceSpanProcessor {

    func onStart(span: ExportableSpan)

    func onEnd(span: ExportableSpan)

    func shutdown()

}
