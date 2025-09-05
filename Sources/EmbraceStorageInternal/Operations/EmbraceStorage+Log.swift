//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

public protocol LogRepository {
    func saveLog(_ log: EmbraceLog)
    func fetchAllLogs(excludingProcessIdentifier processIdentifier: EmbraceIdentifier) -> [EmbraceLog]
    func remove(logs: [EmbraceLog])
}

extension EmbraceStorage {

    public func saveLog(_ log: EmbraceLog) {
        LogRecord.create(context: coreData.context, log: log)
        coreData.save()
    }

    public func fetchAllLogs(excludingProcessIdentifier processIdentifier: EmbraceIdentifier) -> [EmbraceLog] {
        let request = LogRecord.createFetchRequest()
        request.predicate = NSPredicate(format: "processIdRaw != %@", processIdentifier.stringValue)

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
