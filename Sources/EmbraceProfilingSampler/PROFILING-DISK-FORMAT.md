# EmbraceProfiling — on-disk file format (`.embprof`, v1)

This document specifies the on-disk format written by `EmbraceProfilingSampler` when a profiling
session is started in **file-backed mode** (`ProfilingEngine.start(directory:)`). It is the reference
for anyone who needs to read, validate, or recover one of these files independently of the SDK.

The format is versioned. This document describes **format version 1**. All structs are little-endian
and 64-bit; the SDK only supports 64-bit Apple platforms and rejects anything else on recovery.

## 1. Why the format exists

File-backed sessions persist profiling samples so they survive **any** form of process death — a
signal crash, a fatal exception, `abort()`, a watchdog termination, or an OOM / Jetsam `SIGKILL` — and
can be recovered on the next launch.

The mechanism is a **file-backed `MAP_SHARED` memory mapping**: the sampler's ring buffer is backed by
a file instead of anonymous memory. The sampler writes records into mapped memory exactly as it does
in-memory; the kernel's unified buffer cache owns the dirty pages and writes them back to the file.
When the process dies, the kernel still flushes those dirty pages to the file — so the file reflects
recent samples **with no explicit I/O on the sampling hot path**.

The one case this does *not* cover is hard device power loss or a kernel panic (dirty pages not yet
written to flash are lost). That is out of scope for app-crash recovery.

## 2. File layout

Descriptive metadata lives in a **footer at the tail of the file**, not a header at the front. The
data region sits at file offset 0; everything that describes it — and everything that may grow or
change across future format versions — follows it. The file ends with a **frozen identity struct**
(`magic` + `format_version`) that is the only part of the format guaranteed never to change.

```
┌──────────────────────────────────────────────┐  offset 0
│  Data region  (data_capacity bytes)           │  ← page-aligned; same record layout as the
│  variable-length profiling records            │    in-memory ring buffer (§4)
├──────────────────────────────────────────────┤  offset = data_capacity
│  Footer  (footer_bytes, = 2 pages)            │
│   ├─ control page   (hot, read/write)         │  write_pos, oldest_pos, next_seq, status_flags
│   └─ metadata page  (write-once, read-only)   │
│        ├─ descriptor  (at page start)         │  created times, session_id
│        │        …                             │
│        ├─ trailer     (before identity)       │  offsets, page size, record sizes  (v1-specific)
│        └─ identity    (last bytes of file)    │  magic + format_version  (FROZEN, all versions)
└──────────────────────────────────────────────┘  EOF
```

- **File size** is exactly `data_capacity + footer_bytes`. The file is **pre-sized** at creation
  (`ftruncate`) and never appended to at runtime, so a crash can never truncate away the footer.
- **`data_capacity`** is the page-aligned ring capacity (the SDK default is 1 MB; the configurable
  request must be greater than 128 KB and at most 10 MB, then rounded up to a page).
- **`footer_bytes`** is two pages: one read/write *control page* followed by one write-once
  *metadata page*.
- **`page_size`** is `vm_page_size` at creation time (16 KB on Apple-silicon devices and macOS, 4 KB
  on the x86_64 simulator). It is recorded in the trailer so recovery never has to assume it.

### 2.1 Why the metadata is at the tail

- **The data region stays at offset 0 in every format version.** Growing the metadata never moves
  it, and the data region maps cleanly from offset 0.
- **A fixed-position identity at EOF is a capacity-independent discovery point.** A reader does
  `fstat` → reads the last 16 bytes → checks `magic` → reads `format_version` → then parses the rest
  with the parser for that version. The version is known *before* any layout that could have changed
  between versions is touched. (This is the classic extensible-container pattern, e.g. ZIP's
  end-of-central-directory record.)
- **"At the tail" means spatially at the end of the file, not "written last."** The descriptor,
  trailer, and identity are all written **at create time** into pre-sized, page-aligned pages, so
  they flush early and stay on disk regardless of how the process dies.

## 3. On-disk structures (format version 1)

All of these are defined in `Sources/EmbraceProfilingSampler/include/emb_profile_store.h` and
`emb_ring_buffer.h`.

```c
#define EMB_PROFILE_FILE_MAGIC     0x454D422D50524F46ULL  // "EMB-PROF"; also an endianness marker
#define EMB_PROFILE_FORMAT_VER     1u                     // this document
#define EMB_PROFILE_FORMAT_INVALID 0u                     // "disregard this file" — see §5

// Frozen identity — the LAST 16 bytes of the file. Same layout in every format version, forever.
// Discovered via fstat + read(EOF − 16).
typedef struct {
    uint64_t magic;           // EMB_PROFILE_FILE_MAGIC
    uint64_t format_version;  // selects the parser for everything else; 0 = disregard (§5)
} emb_profile_ident_t;        // exactly 16 bytes, no padding — never change this layout

// Version-1 trailer — sits immediately before the identity struct. May change in a future version;
// a reader only parses it after the identity has told it the version is 1.
typedef struct {
    uint64_t footer_offset;        // == data_capacity; where the footer begins
    uint64_t data_capacity;        // data region size in bytes (page-aligned)
    uint32_t page_size;            // page size used at creation
    uint16_t record_header_bytes;  // sizeof(record header); validated on recovery
    uint16_t pointer_bytes;        // sizeof(uintptr_t) == 8
    uint32_t footer_bytes;         // total footer size
    uint32_t trailer_bytes;        // sizeof(this struct) for THIS version — lets a reader step back
                                   // from the identity to the start of the v1 trailer
} emb_profile_trailer_v1_t;

// Write-once static descriptor — at the start of the metadata page.
typedef struct {
    uint64_t created_uptime_ns;    // CLOCK_MONOTONIC_RAW at creation
    uint64_t created_wall_ns;      // wall clock at creation (session correlation)
    uint8_t  session_id[16];       // opaque 128-bit id supplied by the caller
    uint64_t image_table_offset;   // reserved; always 0 in v1 (§6)
    uint64_t image_table_bytes;    // reserved; always 0 in v1 (§6)
} emb_profile_descriptor_t;

// Live control block — the first footer page (read/write for the whole session).
typedef struct {
    _Atomic uint64_t write_pos;    // monotonic write position (absolute byte counter)
    _Atomic uint64_t oldest_pos;   // position of the oldest surviving record
    uint64_t         next_seq;     // writer-local seqlock counter (single writer)
    _Atomic uint32_t status_flags; // Reserved. Session lifecycle is signaled via format_version
                                   // (§5), NOT here.
} emb_ring_control_t;
```

**`trailer_bytes` vs `sizeof`:** the trailer records its own size so a *future* build reading a v1
file knows the on-disk v1 trailer size without hardcoding it — `sizeof` in a newer build would be the
newer struct's size. This is what lets the trailer grow in a later version without stranding old files.

## 4. Record layout (the data region)

The data region is **byte-for-byte the same record layout the in-memory ring buffer uses**, so the
same reader walks both. Each record is a fixed 16-byte header followed by `frame_count` frame
addresses (`uintptr_t`, 8 bytes each):

```c
typedef struct {
    uint32_t seq;           // internal seqlock value (torn-read detection); ignore when reading
    uint16_t frame_count;   // number of frames that follow (1 … EMB_MAX_STACK_FRAMES = 1024)
    uint8_t  thread_state;  // main-thread run state at capture — see PROFILING-THREAD-STATE.md
    uint8_t  flags;         // packed per-sample flags (idle / swapped / truncated) — internal in v1
    uint64_t timestamp_ns;  // CLOCK_MONOTONIC_RAW timestamp
} emb_ring_record_header_t;  // exactly 16 bytes

record_size = sizeof(header) + frame_count * sizeof(uintptr_t)
```

`write_pos` and `oldest_pos` are **absolute monotonic byte counters** (they only ever grow); the
byte offset of a record within the data region is `pos % data_capacity`. The data region is mapped
twice back-to-back at runtime so a record that wraps past the end is still contiguous in memory. The
`thread_state` and `flags` bytes are documented in
[PROFILING-THREAD-STATE.md](PROFILING-THREAD-STATE.md).

## 5. `format_version` as the validity marker

`format_version` in the frozen identity doubles as the file's transactional validity / tombstone
marker. **`0` (`EMB_PROFILE_FORMAT_INVALID`) is reserved forever to mean "disregard this file".** It
is written in two situations:

- **Transiently, while the file is mid-mutation** (during create, before the real version is
  committed; and briefly during an in-place reset). The real version is committed *last*, so a crash
  mid-mutation leaves `0` and the file is safely ignored rather than half-read.
- **As the clean-shutdown tombstone.** When a session is stopped cleanly and its samples have already
  been drained live, `finalizeStorage()` writes `0`. Recovery then reports the file as *finalized*
  (nothing to recover). The file is **never deleted by the SDK** — the host app owns retention.

So on recovery:

| identity state | meaning | outcome |
|---|---|---|
| `magic` mismatch | not one of our files | skip / not ours |
| `format_version == 0` | finalized or mid-mutation | nothing to recover (finalized) |
| `format_version == 1` | a v1 file | parse and recover |
| `format_version` other | written by a newer build | unsupported (kept, not parsed) |

Because the identity layout is frozen, `0` means "ignore" regardless of any future format change, and
a newer `format_version` can always be recognized (and preserved) by an older build even when it can't
parse the contents.

## 6. Recovery

Recovery runs on the launch *after* the one that wrote the file — possibly after an SDK update — off
the hot path. The sequence:

1. `open` (with `O_NOFOLLOW`) + `fstat`; reject non-regular files.
2. Read `emb_profile_ident_t` at `EOF − 16`; validate `magic`; dispatch on `format_version` (§5).
3. For v1, read `emb_profile_trailer_v1_t` immediately before the identity and validate it:
   `page_size`, `record_header_bytes`, `pointer_bytes` must match this build; `data_capacity` must be
   non-zero, page-aligned, and consistent with the real file size (`data_capacity + footer_bytes ==
   file_size`). Any mismatch → the file is treated as corrupt and discarded.
4. Read `write_pos` / `oldest_pos` from the control block and validate them
   (`oldest_pos <= write_pos` and `write_pos − oldest_pos <= data_capacity`). Inconsistent → discard.
5. Walk records from `oldest_pos` toward `write_pos`, emitting each valid record.

**Torn-tail tolerance.** A crash mid-write can leave one partially written record at the head of the
ring. The walk stops cleanly at the first record that is:

- **torn** — the seqlock value is odd (the writer died mid-record), or
- an **unflushed / zeroed** slot — `frame_count == 0`, or
- **garbage** — `frame_count > EMB_MAX_STACK_FRAMES`, or
- an **overrun** — the record's size exceeds the committed span (`write_pos − pos`).

Everything committed before that point is recovered; the partial tail is dropped. Comparing on the
remaining span (`write_pos − pos`, a subtraction that cannot underflow) rather than `pos + size`
avoids an integer-overflow edge case on a crafted file and keeps every read inside the double mapping.

A cheap **peek** path (`emb_profile_peek`) reads only the 16-byte identity to classify a file as
recoverable / finalized / not-ours without walking any records — this is what
`ProfilingEngine.recoverableSessions(in:)` uses to enumerate a directory at launch.

## 7. Runtime hardening (not on disk, but part of the integrity story)

The footer is irreplaceable — corrupt the identity, trailer, or descriptor and the file becomes
unrecoverable. Two hot-path-free defenses protect it against a runaway sequential write out of the
data region:

- **A guard page.** At runtime the reservation places an unmapped `PROT_NONE` page immediately after
  the (double-mapped) data region, before the footer. A sequential overrun traps (`SIGSEGV`/`SIGBUS`)
  before it can reach any metadata. This costs one page of address space, no RAM and no file bytes.
- **Write-once pages made read-only.** After the descriptor / trailer / identity are written at
  create time, the metadata page is dropped to read-only (`mprotect(PROT_READ)`), so any stray store
  into it faults immediately. The control page stays writable (it is updated every sample).

Converting silent footer corruption into an immediate fault is a net win: the on-disk metadata stays
intact (the file stays recoverable), every sample written before the runaway survives, and the fault
itself is a crash the next launch recovers from.

## 8. Where the files live & data protection

- The **directory is provided by the caller** (`ProfilingEngine.start(directory:)`); the profiling
  module does no path policy of its own. There is **one file per session**, named
  `<session-id-hex>.embprof` (the 16-byte session id rendered as 32 hex characters). The active
  session's file belongs to the current process; any *other* `.embprof` file present at launch is a
  previous session that may be recoverable.
- **iOS data protection:** on data-protection platforms the file is created with protection class B
  (`NSFileProtectionCompleteUnlessOpen`), so an open file keeps accepting writes while the device is
  locked (the SDK holds it open for the whole session). Without this, late samples would be lost when
  the screen locks. This is not applied on macOS.

## 9. Versioning & forward-compatibility

Recovery can happen after an SDK update, so forward-compatibility is built in:

- The frozen 16-byte identity is found independently of capacity or format growth and names
  `format_version` **before** any version-dependent layout is parsed.
- Everything else — trailer, descriptor, control block — is parsed by the version-specific parser
  selected from that one field, so any of those may change layout in a future version without
  breaking an older reader's ability to *recognize* the file and pick a parser (or to safely skip a
  file written by a newer build).
- `record_header_bytes`, `pointer_bytes`, `page_size`, and `data_capacity` are all validated on
  recovery, so a file that doesn't match this build's assumptions is rejected rather than misread.

## Appendix: reserved for future versions

The descriptor carries `image_table_offset` / `image_table_bytes`, both **0 in v1**. They reserve
space for an optional per-file **image table** (binary UUID + load address + path) that would let a
recovered session be symbolicated entirely from its own file, without correlating against the live
process's image list. v1 emits raw return addresses plus the `session_id`; symbolication of recovered
samples is handled by the host SDK using its per-session image list. Because the format is
tail-versioned, an image table can be added later without a breaking format change.
