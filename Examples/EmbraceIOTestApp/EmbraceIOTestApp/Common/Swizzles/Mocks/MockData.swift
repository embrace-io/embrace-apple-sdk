//
//  MockData.swift
//  EmbraceIOTestApp
//
//

import Foundation

struct MockData {
    static var mockConfig: Data {
                    """
                    {
                      "event_limits": {},
                      "personas": [],
                      "ls": 100,
                      "disabled_message_types": [],
                      "ui": {
                        "views": 100,
                        "web_views": 100
                      },
                      "ui_load_instrumentation_enabled": true,
                      "signal_strength_enabled": false,
                      "screenshots_enabled": false,
                      "disable_session_control": false,
                      "logs": {
                        "max_length": 4000
                      },
                      "urlconnection_request_enabled": true,
                      "threshold": 100,
                      "offset": 0,
                      "session_control": {
                        "enable": true,
                        "async_end": false
                      }
                    }
                    """.toData()!
    }
}
