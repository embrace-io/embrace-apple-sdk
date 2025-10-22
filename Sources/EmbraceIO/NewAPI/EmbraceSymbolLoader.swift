//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Darwin
import Foundation

struct OptionsGetter {

    typealias EmbraceIOSetupGetOptionsFunctionPtr = @convention(c) () -> Embrace.Options

    static func get() -> Embrace.Options {
        if let getOptions: EmbraceIOSetupGetOptionsFunctionPtr = _loadSymbol(
            name: "EmbraceIOSetupGetOptions",
            as: EmbraceIOSetupGetOptionsFunctionPtr.self,
            from: nil
        ) {
            getOptions()
        } else {
            Embrace.Options(
                appId: Bundle.main.infoDictionary?["EMBApplicationId"] as? String ?? "12345"
            )
        }
    }

    static func _loadSymbol<T>(name: String, as type: T.Type, from path: String? = nil) -> T? {
        // If path is nil, open the main program image; otherwise open the dylib at `path`
        let handle = dlopen(path, RTLD_NOW)  // nil path == main program on Apple platforms
        guard handle != nil else {
            return nil
        }
        guard let sym = dlsym(handle, name) else {
            return nil
        }
        return unsafeBitCast(sym, to: T.self)
    }
}
