//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

class LogDataValidation {

    let validators: [LogDataValidator]

    init(validators: [LogDataValidator]) {
        self.validators = validators
    }

    /// Validators have the opportunity to modify the ReadableLogRecord if any validation is deemed recoverable
    /// - Parameter log The data to validate. An inout parameter as this item can be mutated by any validator
    /// - Returns false if any validator fails
    func execute(log: inout EmbraceLog) -> Bool {
        var result = true

        for validator in validators {
            result = result && validator.validate(data: &log)
            guard result else { break }
        }

        return result
    }
}
