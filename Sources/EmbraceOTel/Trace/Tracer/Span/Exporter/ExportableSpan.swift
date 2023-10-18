//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

public protocol ExportableSpan {

    /// Retrieve a snapshot of the span data
    var spanData: SpanData { get }
}
