//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import UIKit

@Observable
class MemoryPressureSimulator {
    private var notificationCenter: NotificationCenter
    private var dataStorage: [Data]
    private var timer: Timer?

    var totalMemoryBytes: Int
    var isSimulating: Bool

    init(
        totalMemoryBytes: Int = 0,
        isSimulating: Bool = false,
        dataStorage: [Data] = [],
        timer: Timer? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.totalMemoryBytes = totalMemoryBytes
        self.isSimulating = isSimulating
        self.dataStorage = dataStorage
        self.timer = timer
        self.notificationCenter = notificationCenter
        self.notificationCenter.addObserver(
            self,
            selector: #selector(self.handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    func startSimulating() {
        isSimulating = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else {
                return
            }
            let dataSize = 10 * 1024 * 1024  // 10 MB
            let data = Data(repeating: 0, count: dataSize)
            self.dataStorage.append(data)
            self.totalMemoryBytes += data.count
        }
    }

    func stopSimulating() {
        isSimulating = false
        timer?.invalidate()
        timer = nil
        dataStorage.removeAll()
        totalMemoryBytes = 0
        print("Simulation stopped and memory cleared.")
    }

    @objc
    func handleMemoryWarning() {
        print("Did Receive Memory Warning")
        stopSimulating()
    }
}
