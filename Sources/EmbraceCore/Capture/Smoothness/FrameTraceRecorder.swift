//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    /// Records a focal moment's frame trace: each tick's interval since the previous tick, in whole
    /// milliseconds (truncated, like Android), as an unsigned LEB128 varint. The buffer is allocated once
    /// per recorder rather than per moment.
    ///
    /// Ticks are written as they arrive and kept once `commit()` marks an activity tick, so idle ticks
    /// between activity are kept and trailing ones are dropped, matching `frame_count`. Writing stops at
    /// the first varint that doesn't fit, so a capped trace is always a prefix. Android skips that
    /// varint and keeps writing smaller ones, which can leave a gap.
    ///
    /// Not thread-safe: `FocalMomentTracker` calls it with its lock held.
    final class FrameTraceRecorder {

        static let defaultCapacity = 1024

        init(capacity: Int = FrameTraceRecorder.defaultCapacity) {
            buffer = [UInt8](repeating: 0, count: capacity)
        }

        /// Starts a new moment's trace.
        func reset() {
            written = 0
            committed = 0
            isFull = false
        }

        func record(_ tick: FrameTimingSource.Tick) {
            guard !isFull else { return }

            let milliseconds = max(0, tick.timestamp - tick.previousTimestamp) * 1000
            write(UInt64(milliseconds))
        }

        /// Keeps every tick recorded so far.
        func commit() {
            committed = written
        }

        var trace: Data? {
            committed > 0 ? Data(buffer[0..<committed]) : nil
        }

        // MARK: - Private

        private var buffer: [UInt8]
        private var written = 0
        private var committed = 0
        private var isFull = false

        private func write(_ value: UInt64) {
            var remaining = value
            var index = written
            while true {
                guard index < buffer.count else {
                    isFull = true
                    return
                }
                let septet = UInt8(remaining & 0x7F)
                remaining >>= 7
                if remaining == 0 {
                    buffer[index] = septet
                    written = index + 1
                    return
                }
                buffer[index] = septet | 0x80
                index += 1
            }
        }
    }

#endif  // !os(watchOS) && !os(macOS)
