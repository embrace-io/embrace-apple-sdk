//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

protocol EmbraceSpanDelegate: AnyObject {
    func onSpanStatusUpdated(_ span: EmbraceSpan, status: EmbraceSpanStatus)
    func onSpanEventAdded(_ span: EmbraceSpan, event: EmbraceSpanEvent)
    func onSpanLinkAdded(_ span: EmbraceSpan, link: EmbraceSpanLink)
    func onSpanAttributeUpdated(_ span: EmbraceSpan, attributes: [String: String])
    func onSpanEnded(_ span: EmbraceSpan, endTime: Date)
}
