//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
import Foundation

public func withExtendedBackgroundLifetime(_ name: String = #function, onExpire: (() -> Void)? = nil, _ block: () -> Void) {
    guard let task = BackgroundTaskWrapper(
        name: name,
        expirationBlock: onExpire
    ) else {
        return
    }
    defer { task.finish() }
    block()
}

public func withExtendedBackgroundLifetime(_ name: String = #function, _ block: @escaping () async throws -> Void) async {
    
    var task: Task<Void, Error>? = nil
    
    guard let backgroundTask = BackgroundTaskWrapper(
        name: name,
        expirationBlock: {
            print("withExtendedBackgroundLifetime expired")
            task?.cancel()
        }
    ) else {
        return
    }
    defer {
        print("withExtendedBackgroundLifetime exiting")
        backgroundTask.finish()
    }
    
    do {
        task = Task {
            try await block()
        }
        try await task?.value
    } catch is CancellationError {
        print("withExtendedBackgroundLifetime was cancelled")
    } catch {
        print("withExtendedBackgroundLifetime error \(error)")
    }
}
