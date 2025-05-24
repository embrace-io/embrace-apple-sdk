//
//  EmbraceInitScreenViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCore

struct EmbraceInitScreenFormSectionItem {
    var name: String
    var value: String = ""
}

struct EmbraceInitScreenFormSection {
    var name: String
    var items: [EmbraceInitScreenFormSectionItem] = []
}

struct EmbraceInitScreenViewModel {
    var embraceHasInitialized: Bool {
        Embrace.client?.state == .started
    }
    var formDisabled: Bool {
        showProgressview || embraceHasInitialized
    }

    var simulateEmbraceAPI: Bool = true

    var formFields: [EmbraceInitScreenFormSection] = [
        .init(name: "APP ID",
              items: [.init(name: "APP ID",
                            value: "AK5HV")]),
        .init(name: "API Base URL",
              items: [.init(name: "Base URL",
                            value: "http://127.0.0.1:8989/api")]),
        .init(name: "Config Base URL",
              items: [.init(name: "Config Base URL",
                            value: "http://127.0.0.1:8989/api")])
    ]

    var appId: String {
        formFields[0].items[0].value
    }
    
    var baseURL: String {
        formFields[1].items[0].value
    }
    
    var configBaseURL: String {
        formFields[2].items[0].value
    }
    
    var showProgressview: Bool = false
}
