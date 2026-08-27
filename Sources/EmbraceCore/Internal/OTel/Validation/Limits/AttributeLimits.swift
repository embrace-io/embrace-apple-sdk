//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

struct AttributeLimits {
    let keyLength: Int
    let valueLength: Int

    init(keyLength: Int = 128, valueLength: Int = 1024) {
        self.keyLength = keyLength
        self.valueLength = valueLength
    }
}
