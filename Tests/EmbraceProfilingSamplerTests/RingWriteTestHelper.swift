//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//
//  Test shims that forward to the widened C APIs with default values for the
//  Phase-2 additions (thread_state/flags on writes, is_truncated on the walker),
//  so the many existing call sites don't each need editing. The first parameters
//  match the C signatures exactly, so every prior call still type-checks.

import EmbraceProfilingSampler

#if !os(watchOS)

@discardableResult
func ringWrite(_ buf: UnsafeMutablePointer<emb_ring_buffer_t>?,
               _ timestampNs: UInt64,
               _ frames: UnsafePointer<UInt>?,
               _ frameCount: Int,
               _ threadState: UInt8 = 0,
               _ flags: UInt8 = 0) -> emb_ring_write_status_t {
    emb_ring_buffer_write(buf, timestampNs, frames, frameCount, threadState, flags)
}

@discardableResult
func stackWalk(_ thread: thread_t,
               _ stackBottom: UnsafeRawPointer?,
               _ stackTop: UnsafeRawPointer?,
               _ framesOut: UnsafeMutablePointer<UInt>?,
               _ maxFrames: Int,
               _ countOut: UnsafeMutablePointer<Int>?,
               _ isTruncated: UnsafeMutablePointer<Bool>? = nil) -> Bool {
    emb_stack_walk(thread, stackBottom, stackTop, framesOut, maxFrames, countOut, isTruncated)
}

#endif
