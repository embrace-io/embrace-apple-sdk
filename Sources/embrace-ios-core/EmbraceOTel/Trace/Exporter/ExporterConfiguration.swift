//
//  File.swift
//  
//
//  Created by Austin Emmons on 7/28/23.
//

import Foundation


public extension SpanExporter {
    class ExporterConfiguration {

        let storage: SpanStorage

        init(storage: SpanStorage) {
            self.storage = storage
        }

    }
}
