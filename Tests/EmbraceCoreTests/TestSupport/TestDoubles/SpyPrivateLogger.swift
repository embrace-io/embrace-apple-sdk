//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

class SpyPrivateLogger: EmbracePrivateLogger {

    var didCallSendPrivateLog = false
    var sendPrivateLogReceivedMessages: [String] = []

    func sendPrivateLog(_ message: String) {
        didCallSendPrivateLog = true
        sendPrivateLogReceivedMessages.append(message)
    }
}
