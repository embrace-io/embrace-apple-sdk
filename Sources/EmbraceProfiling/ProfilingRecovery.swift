//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !os(watchOS)
    // See ProfilingEngine.swift: under CocoaPods this module is part of EmbraceIO, not importable.
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceProfilingSampler
    #endif
#endif

/// An opaque handle to one previous session's persisted profiling file, discovered via
/// ``ProfilingEngine/recoverableSessions(in:)``. Carries identifying metadata so the caller can decide
/// what to recover or delete without touching the underlying file directly. Recover it with
/// ``ProfilingEngine/recover(_:)`` and remove it with ``ProfilingEngine/delete(_:)``.
public struct RecoverableSession: Sendable, Equatable {
    /// What a cheap identity peek says about the file.
    public enum Status: Sendable {
        /// Has (or may have) un-reported samples — worth recovering.
        case recoverable
        /// Nothing to recover, safe to delete. Reached by a clean stop (`finalize`), and — because
        /// both write a 0 version marker — also by a crash mid-`reset`. Not a proof of normal shutdown.
        case finalized
    }

    /// Hex session id (the file-name stem).
    public let sessionId: String
    /// When the file was last written (its most recent sample or the finalize tombstone).
    public let lastModified: Date
    /// On-disk size in bytes.
    public let byteSize: Int
    /// Whether this session has data to recover or was cleanly finalized.
    public let status: Status

    /// The backing file. Internal so callers act through `recover(_:)`/`delete(_:)`, never the raw path.
    let url: URL
}

/// Outcome of recovering a single ``RecoverableSession``.
public enum SessionRecoveryResult: Sendable {
    /// Parsed successfully; the (possibly empty) samples for this session.
    case recovered(ProfilingResult)
    /// The file was cleanly finalized — nothing to recover.
    case finalized
    /// The file could not be parsed (not ours / unsupported / corrupt / I/O error).
    case unreadable(reason: String)
    /// Profiling is not supported on this platform (e.g. watchOS).
    case notSupported
}

#if !os(watchOS)

    /// Per-file accumulator the C recovery callback writes into (a class so it can be mutated via the
    /// opaque `ctx` pointer from a non-capturing C function pointer).
    private final class FileSink {
        var samples: [ProfilingSample] = []
        var frames: [UInt] = []
    }

    private let recoverEmit: emb_profile_record_cb = { ctx, ts, state, _, framesPtr, count in
        let sink = Unmanaged<FileSink>.fromOpaque(ctx!).takeUnretainedValue()
        let start = sink.frames.count
        if let framesPtr, count > 0 {
            sink.frames.append(contentsOf: UnsafeBufferPointer(start: framesPtr, count: Int(count)))
        }
        sink.samples.append(ProfilingSample(
            timestamp: ts,
            frameRange: start..<sink.frames.count,
            threadState: ThreadState(rawValue: state) ?? .unknown))
    }

    private func describe(_ status: emb_profile_recover_status_t, errno errnoValue: Int32) -> String {
        switch status {
        case EMB_PROFILE_RECOVER_NOT_OURS: return "not an Embrace profiling file"
        case EMB_PROFILE_RECOVER_UNSUPPORTED: return "unsupported format version"
        case EMB_PROFILE_RECOVER_CORRUPT: return "corrupt (failed validation)"
        case EMB_PROFILE_RECOVER_IO_ERROR:
            return errnoValue != 0 ? "I/O error (errno \(errnoValue))" : "I/O error"
        default: return "unknown status \(status.rawValue)"
        }
    }

#endif

extension ProfilingEngine {
    /// List previous sessions persisted in `directory` (the same directory passed to a file-backed
    /// `start`). **Cheap and read-only** — reads only file metadata + a 16-byte identity peek per file,
    /// never loading samples — so it's safe to call at launch. Skips the currently-active session's file
    /// and anything that isn't one of ours. Returns handles sorted oldest-first by `lastModified`.
    ///
    /// Recover each with ``recover(_:)`` and remove it with ``delete(_:)`` (Embrace owns retention).
    public func recoverableSessions(in directory: URL) -> [RecoverableSession] {
        #if os(watchOS)
            return []
        #else
            let fm = FileManager.default
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else {
                return []
            }
            let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
            guard let entries = try? fm.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: keys) else {
                return []
            }

            // Snapshot the active file name under the gate so we don't race start()/teardown.
            // If we can't acquire the gate we can't prove which file is live, so we must not risk
            // handing the caller the active session's file — bail conservatively (contention is
            // extremely rare and the caller can retry). A successful acquire with a nil name simply
            // means nothing is active, which is safe.
            guard acquireBackingGate() else { return [] }
            let activeName = activeSessionFileName
            releaseBackingGate()

            var sessions: [RecoverableSession] = []
            for url in entries
                where url.pathExtension == Self.sessionFileExtension && url.lastPathComponent != activeName {
                let peek = url.path.withCString { emb_profile_peek($0) }
                let status: RecoverableSession.Status
                switch peek {
                case EMB_PROFILE_PEEK_RECOVERABLE: status = .recoverable
                case EMB_PROFILE_PEEK_FINALIZED: status = .finalized
                case EMB_PROFILE_PEEK_INDETERMINATE:
                    // Couldn't read the file this launch (e.g. still locked under data protection at
                    // boot, or a transient I/O error). It may be one of ours and recoverable — we just
                    // can't tell yet — so skip it this pass rather than misclassify it. It stays on disk
                    // (we never delete here) and is re-examined on the next launch. Kept distinct from
                    // NOT_OURS so retention/cleanup logic won't treat it as safe to delete.
                    continue
                default: continue  // not ours → skip
                }
                // `keys` were pre-fetched by contentsOfDirectory above, so this read hits the cache and
                // effectively only fails if the file vanished mid-enumeration — in which case the handle
                // is about to be useless anyway. The sentinels aren't neutral (`.distantPast` sorts to the
                // front of the oldest-first list below), so the values stay non-optional deliberately:
                // callers shouldn't have to unwrap for a case that doesn't meaningfully occur.
                let values = try? url.resourceValues(forKeys: Set(keys))
                sessions.append(RecoverableSession(
                    sessionId: url.deletingPathExtension().lastPathComponent,
                    lastModified: values?.contentModificationDate ?? .distantPast,
                    byteSize: values?.fileSize ?? 0,
                    status: status,
                    url: url))
            }
            return sessions.sorted { $0.lastModified < $1.lastModified }
        #endif
    }

    /// Recover one session's samples. **Read-only** — never writes, tombstones, or deletes the file.
    /// Runs synchronously; call it off the main thread. Recovering a `.finalized` handle returns
    /// ``SessionRecoveryResult/finalized``.
    public func recover(_ session: RecoverableSession) -> SessionRecoveryResult {
        #if os(watchOS)
            return .notSupported
        #else
            let sink = FileSink()
            var errnoOut: Int32 = 0
            let status = session.url.path.withCString { path in
                emb_profile_recover(path, recoverEmit, Unmanaged.passUnretained(sink).toOpaque(), &errnoOut)
            }
            switch status {
            case EMB_PROFILE_RECOVER_OK:
                return .recovered(ProfilingResult(samples: sink.samples, frames: sink.frames))
            case EMB_PROFILE_RECOVER_FINALIZED:
                return .finalized
            default:
                return .unreadable(reason: describe(status, errno: errnoOut))
            }
        #endif
    }

    /// Delete a previous session's file (Embrace owns retention — call when you're done with it,
    /// whether recovered or finalized). Refuses to delete the currently-active session's file. Returns
    /// `true` if the file was removed.
    @discardableResult
    public func delete(_ session: RecoverableSession) -> Bool {
        #if os(watchOS)
            return false
        #else
            // Gate acquisition failure means we can't confirm the file isn't the live session, so
            // treat it as a hard "don't delete" rather than falling through to a nil active name
            // (which would let us delete the currently-active file — a data-loss bug).
            guard acquireBackingGate() else { return false }
            let activeName = activeSessionFileName
            releaseBackingGate()
            guard session.url.lastPathComponent != activeName else { return false }
            return (try? FileManager.default.removeItem(at: session.url)) != nil
        #endif
    }
}
