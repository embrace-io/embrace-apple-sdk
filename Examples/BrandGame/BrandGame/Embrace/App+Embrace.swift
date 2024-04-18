//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import StdoutExporter

extension BrandGameApp {
#if DEBUG
    // https://dash.embrace.io/app/AK5HV
    var embraceOptions: Embrace.Options {
        return .init(
            appId: "AK5HV",
            appGroupId: nil,
            platform: .default,
            endpoints: Embrace.Endpoints.fromInfoPlist(),
            logLevel: .debug,
            export: otelExport
        )
    }

    private var otelExport: OpenTelemetryExport {
        OpenTelemetryExport(
            spanExporter: StdoutExporter(isDebug: true),
            logExporter: StdoutLogExporter(isDebug: true)
        )
    }

#else
    // https://dash.embrace.io/app/kj9hd
    var embraceOptions: Embrace.Options {
        return .init(
            appId: "kj9hd",
            appGroupId: nil,
            platform: .iOS
        )
    }
#endif

}
