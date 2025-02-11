//
//  LogTestUIComponentViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

class LogTestUIComponentViewModel: UIComponentViewModelBase {
    var logExporter: TestLogRecordExporter

    init(logExporter: TestLogRecordExporter, dataModel: any TestScreenDataModel) {
        self.logExporter = logExporter
        super.init(dataModel: dataModel)
    }
}
