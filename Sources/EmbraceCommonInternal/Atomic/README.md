# EmbraceAtomic

A simple, type-safe wrapper for atomic operations in Swift, backed by C11/C++11 atomics.

## Why Our Own Implementation?

While there are standard atomic implementations available, we maintain our own for compatibility reasons:

- **Apple's Synchronization framework**: Includes native atomic types, but they're only available on iOS 18+ (and equivalent versions on other platforms). We need to support iOS versions much further back.
- **Swift-Atomics package**: Provides excellent atomic primitives, but is only distributed via Swift Package Manager. Our SDK also supports CocoaPods, requiring a solution that works across all package managers.

By maintaining our own lightweight implementation, we ensure atomic operations work consistently across all supported iOS versions and distribution methods.

## What are Atomics?

Atomics provide thread-safe operations on primitive values without using locks. When multiple threads access the same variable, atomics guarantee that each operation completes as a single, indivisible unit—preventing data races and ensuring memory consistency.

## Why Use Atomics?

Use atomics instead of locks when you need:
- **Simple shared state**: Counters, flags, or single primitive values accessed from multiple threads
- **Lock-free performance**: Atomics are typically faster than locks for simple operations

**Don't use atomics for:**
- Complex state updates involving multiple values (use locks or actors instead)
- Operations requiring multiple steps to be atomic together
- When readability is more important than performance (locks are often clearer)

## When to Use Atomics

Common use cases:
- **Reference counting**: Track object lifetimes across threads
- **Thread-safe flags**: Signal state between threads (e.g., shutdown flags, initialization flags)
- **Shared counters**: Increment/decrement values from multiple threads
- **Simple state machines**: Manage basic states without complex transitions

## How to Use

### Basic Example

```swift
import EmbraceCommonInternal

// Create an atomic counter
let counter = EmbraceAtomic<Int32>(0)

// Read the current value
let value = counter.load()  // returns 0

// Update the value
counter.store(42)

// Atomically increment and get the previous value
let previous = counter.fetchAdd(1)  // returns 42, counter is now 43

// Shorthand operators for arithmetic types
counter += 10  // counter is now 53
counter -= 3   // counter is now 50
```

### Thread-Safe Flag Example

```swift
// Create a flag to signal shutdown
let shouldShutdown = EmbraceAtomic<Bool>(false)

// Thread 1: Check the flag
if shouldShutdown.load() {
    // Perform cleanup
}

// Thread 2: Signal shutdown
shouldShutdown.store(true)

// Toggle a flag
let newValue = shouldShutdown.toggle()  // returns true if now true, false if now false
```

### Advanced: Compare-and-Swap

```swift
let state = EmbraceAtomic<Int32>(0)

// Only update if the current value is 0
var expected: Int32 = 0
if state.compareExchange(expected: &expected, desired: 1) {
    // Successfully changed from 0 to 1
} else {
    // Failed: expected now contains the actual current value
}
```

## Memory Ordering

**TL;DR: Just use the defaults.** Unless you're optimizing critical performance code and understand the implications, the default ordering (`.sequencialConsistency`) is what you want.

### What is Memory Ordering?

When multiple threads access atomics, memory ordering controls how changes become visible between threads. Think of it like synchronization rules that determine when one thread can see updates made by another.

### Available Orderings (From Safest to Fastest)

#### `.sequencialConsistency` (Default) — Use This

**What it does:** All threads see all atomic operations in the same order. It's like everyone watching the same movie—no confusion about what happened when.

**When to use:** Always, unless you have a proven performance bottleneck and deep expertise.

```swift
let counter = EmbraceAtomic<Int32>(0)
counter.store(42)              // Uses sequential consistency by default
let value = counter.load()     // Also uses sequential consistency
```

#### `.acquireAndRelease` — Read-Modify-Write

**What it does:** Combines acquire (when reading) and release (when writing) semantics. Used for operations that both read and write.

**When to use:** Operations like `fetchAdd`, `compareExchange`, or `exchange` when you need synchronization but want slightly better performance than sequential consistency.

```swift
// Example: Thread-safe incrementing where you need to see previous updates
let requestCount = EmbraceAtomic<Int32>(0)
let previous = requestCount.fetchAdd(1, order: .acquireAndRelease)
// You'll see all writes that happened before this, and your write will be
// visible to others who acquire after this
```

#### `.acquire` — Reading Shared Data

**What it does:** When you load a value, you're guaranteed to see all writes that happened before a corresponding release operation.

**When to use:** Loading a flag/value after another thread has set it up with `.release`.

```swift
// Thread 1: Producer sets up data then releases flag
dataBuffer.write(someData)
isReady.store(true, order: .release)  // All writes above are visible

// Thread 2: Consumer acquires flag then reads data
if isReady.load(order: .acquire) {    // Can now safely see the data writes
    let data = dataBuffer.read()
}
```

#### `.release` — Publishing Shared Data

**What it does:** When you store a value, all your previous writes become visible to threads that acquire this value.

**When to use:** Storing a flag/value after you've set up data that other threads need.

```swift
// Publish a result after computing it
result.store(computedValue, order: .release)
// Any thread that loads with .acquire will see this value
```

#### `.relaxed` — No Synchronization (Advanced)

**What it does:** Only guarantees the atomic operation itself is indivisible, but provides no ordering guarantees with other memory operations.

**When to use:** Very rare. Only for counters or flags where you don't care about the order of operations, just that they're atomic (e.g., statistics counters that are read infrequently).

```swift
// Example: Simple counter where exact ordering doesn't matter
let statsCounter = EmbraceAtomic<Int32>(0)
statsCounter.fetchAdd(1, order: .relaxed)  // Just count, don't synchronize
```

**⚠️ Warning:** Using `.relaxed` incorrectly can cause subtle bugs. Avoid unless you're certain.

### Quick Decision Guide

```
┌─────────────────────────────────────────────────────────┐
│ Do you have a proven performance bottleneck?            │
│                                                           │
│  NO  → Use default (nothing to specify)                 │
│  YES → Are you an expert in memory ordering?            │
│         NO  → Use default                                │
│         YES → Consider .acquireAndRelease or .relaxed   │
└─────────────────────────────────────────────────────────┘
```

## Supported Types

`EmbraceAtomic` works with the following types:
- **Signed integers**: `Int8`, `Int16`, `Int32`, `Int64`
- **Unsigned integers**: `UInt8`, `UInt16`, `UInt32`, `UInt64`
- **Floating-point**: `Double`
- **Boolean**: `Bool`

## API Reference

### All Types

- `init(_ initial: T)`: Create an atomic with an initial value
- `load(order:)`: Read the current value
- `store(_ value:, order:)`: Write a new value
- `exchange(_ value:, order:)`: Atomically replace with a new value, return the old value
- `compareExchange(expected:, desired:, successOrder:)`: Compare-and-swap operation

### Arithmetic Types Only

Integer and Double types support additional operations:
- `fetchAdd(_ delta:, order:)`: Atomically add and return the previous value
- `fetchSub(_ delta:, order:)`: Atomically subtract and return the previous value
- `+=`: Shorthand for atomic add
- `-=`: Shorthand for atomic subtract

### Bool Only

- `toggle(order:)`: Atomically flip the boolean and return the new value
