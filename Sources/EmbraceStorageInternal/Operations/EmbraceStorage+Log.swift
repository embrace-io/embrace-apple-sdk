//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

public protocol LogRepository {
    func saveLog(_ log: EmbraceLog)
    func fetchAllLogs(excludingProcessIdentifier processIdentifier: EmbraceIdentifier?) -> [EmbraceLog]
    func remove(logs: [EmbraceLog])
}

extension EmbraceStorage {

    /// Saves a log to the storage asynchronously, without blocking the calling thread.
    ///
    /// The operation runs on the storage's serial context, so any storage operation issued after
    /// this call (fetching or removing logs) observes the saved record.
    public func saveLog(_ log: EmbraceLog) {
        coreData.performAsyncOperation(save: true) { context in
            LogRecord.create(context: context, log: log)
        }
    }

    public func fetchAllLogs(excludingProcessIdentifier processIdentifier: EmbraceIdentifier? = nil) -> [EmbraceLog] {
        let request = LogRecord.createFetchRequest()
        if let processIdentifier {
            request.predicate = NSPredicate(format: "processIdRaw != %@", processIdentifier.stringValue)
        }

        // fetch
        var result: [EmbraceLog] = []
        coreData.fetchAndPerform(withRequest: request) { records, _ in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    public func remove(logs: [EmbraceLog]) {

        var predicates: [NSPredicate] = []

        for log in logs {
            predicates.append(
                NSPredicate(
                    format: "id == %@ AND processIdRaw == %@",
                    log.id,
                    log.processId.stringValue
                ))
        }

        let request = LogRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

        coreData.deleteRecords(withRequest: request)
    }
}
