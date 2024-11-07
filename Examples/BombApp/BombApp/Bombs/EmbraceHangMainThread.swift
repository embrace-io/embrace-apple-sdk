//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

class EmbraceHangMainThread: CRLCrash {
    override var category: String { return "Embrace" }
    override var title: String { return "Embrace Hang MainThread" }
    override var desc: String { return "Generate a never-ending hang in the main thread" }

    override func crash() {
        DispatchQueue.main.async {
            while true {
                let largeArray = Array(repeating: 0, count: 10_000_000)
                let _ = largeArray.sorted()
            }
        }
    }
}
