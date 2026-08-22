# EmbraceProfiling — per-sample thread run state

Every profiling sample records the **run state of the main thread** at the moment of capture —
running vs. blocked/waiting. This is what lets a flame graph separate genuine on-CPU hotspots from
off-CPU (blocked or idle) stacks, which is the signal that makes the data useful for hang detection.

The run state occupies the `thread_state` byte of each record header (see
[PROFILING-DISK-FORMAT.md](PROFILING-DISK-FORMAT.md) §4); the adjacent `flags` byte carries a few
per-sample flags.

## 1. Source of the value

The run state comes from Mach's `thread_info` (**not** `thread_get_state`, which returns register
state — that is what the stack walker uses):

```c
thread_basic_info_data_t info;
mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
kern_return_t kr = thread_info(thread, THREAD_BASIC_INFO, (thread_info_t)&info, &count);
// info.run_state ∈ { TH_STATE_RUNNING(1), TH_STATE_STOPPED(2), TH_STATE_WAITING(3),
//                     TH_STATE_UNINTERRUPTIBLE(4), TH_STATE_HALTED(5) }
```

For the main thread the meaningful distinction is **RUNNING** (on-CPU work) vs. **WAITING** (blocked
on a lock or I/O, or idle in the runloop's `mach_msg`).

## 2. Captured *before* the thread is suspended

The sampler captures `thread_info` in the pre-suspend window (where it already reads the stack
bounds), **not** inside the suspended window, for two reasons:

1. **It reads the genuinely-running state.** A thread we have suspended has `suspend_count ≥ 1`;
   whether `thread_suspend` also perturbs `run_state` is an XNU internal we don't want to depend on.
   Reading before suspend captures the running thread's state unambiguously.
2. **`thread_info` is a `mach_msg` RPC, not a cheap trap.** It is not async-signal-safe and, as a
   kernel round-trip, would lengthen the main-thread suspension if run inside the window. Capturing
   it before suspend, on the sampler's own thread, keeps the suspended window microsecond-short.

The trade-off is a tiny race (`thread_info` → suspend, on the order of microseconds) in which the
thread could change state — irrelevant for a coarse RUNNING/WAITING signal that changes on
millisecond scales.

## 3. On-disk enum

The stored byte mirrors the Mach `TH_STATE_*` constants exactly, so the captured `run_state` is
stored directly with no translation:

```c
typedef enum {                                   // fits in uint8_t
    EMB_THREAD_RUN_STATE_RUNNING         = 1,    // == TH_STATE_RUNNING
    EMB_THREAD_RUN_STATE_STOPPED         = 2,    // == TH_STATE_STOPPED
    EMB_THREAD_RUN_STATE_WAITING         = 3,    // == TH_STATE_WAITING
    EMB_THREAD_RUN_STATE_UNINTERRUPTIBLE = 4,    // == TH_STATE_UNINTERRUPTIBLE
    EMB_THREAD_RUN_STATE_HALTED          = 5,    // == TH_STATE_HALTED
    EMB_THREAD_RUN_STATE_UNKNOWN         = 255,  // thread_info failed / not captured
} emb_thread_run_state_t;
```

A `_Static_assert` in `emb_ring_buffer.h` locks these values to the Mach constants so a future header
change can't silently desync them. `UNKNOWN = 255` is a value Mach never returns; it means "couldn't
capture." If a future OS returns a `run_state` outside the known set, it is stored **raw** (still
forward-compatible), and the Swift side maps any unrecognized value to `.unknown`.

On the Swift side this surfaces as `ProfilingSample.threadState`:

```swift
public enum ThreadState: UInt8, Sendable {
    case running = 1, stopped = 2, waiting = 3, uninterruptible = 4, halted = 5, unknown = 255
}
```

The Swift enum and the C enum independently mirror `TH_STATE_*`; the raw values are the shared source
of truth. (A test anchoring the Swift enum to the Mach constants keeps the two from drifting.)

## 4. The `flags` byte

The header's `flags` byte is **the SDK's own packed layout, not a raw copy of Mach's `info.flags`** —
the bit positions are reassigned and one non-Mach flag (`truncated`) is added:

| bit | meaning | source |
|---|---|---|
| 0 | idle | `TH_FLAGS_IDLE` |
| 1 | swapped | `TH_FLAGS_SWAPPED` |
| 2 | truncated | stack exceeded `max_frames` during the walk |
| 3–7 | reserved (0) | — |

In v1 these flags are **internal** — they are stored in the record but not surfaced in the public
Swift API, which exposes `threadState` only.
