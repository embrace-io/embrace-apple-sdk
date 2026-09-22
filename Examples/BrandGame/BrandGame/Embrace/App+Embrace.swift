//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import StdoutExporter

extension BrandGameApp {
    #if DEBUG
        // https://dash.embrace.io/app/dcdt4
        var embraceOptions: EmbraceIO.Options {
            return .withAppId(
                "dcdt4",
                platform: .default,
                endpoints: EmbraceEndpoints.fromInfoPlist(),
                logLevel: .debug,
                otel: otelOptions
            )
        }

        private var otelOptions: EmbraceIO.OTelOptions {
            .init(
                spanExporters: [StdoutSpanExporter(isDebug: true)],
                logExporters: [StdoutLogExporter(isDebug: true)]
            )
        }

    #else
        // https://dash.embrace.io/app/kj9hd
        var embraceOptions: EmbraceIO.Options {
            return .withAppId(
                "kj9hd",
                platform: .default
            )
        }
    #endif

}
