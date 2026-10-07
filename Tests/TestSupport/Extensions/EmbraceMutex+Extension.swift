//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//
import EmbraceCommonInternal

extension EmbraceMutex {
    /// Span processors run synchronously, so calling this from `onStart`/`onEnd`
    /// Tries to take the lock without blocking, returns false if it's being held.
    public var isLockFree: Bool { withLockIfAvailable { _ in } != nil }
}
