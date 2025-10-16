# EmbraceAtomic

A simple, type-safe wrapper for atomic operations in Swift, backed by C11/C++11 atomics.

## What are Atomics?

Atomics provide thread-safe operations on primitive values without using locks. When multiple threads access the same variable, atomics guarantee that each operation completes as a single, indivisible unit—preventing data races and ensuring memory consistency.

## Why Use Atomics?

Use atomics instead of locks when you need:
- **Simple shared state**: Counters, flags, or single primitive values accessed from multiple threads
- **Lock-free performance**: Atomics are typically faster than locks for simple operations
- **Wait-free guarantees**: Operations complete without blocking

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

All operations accept an optional `order` parameter that controls memory visibility across threads:

- **`.sequencialConsistency`** (default): Strongest guarantee—all threads see operations in the same order
- `.acquireAndRelease`: Synchronize with matching operations
- `.acquire`: Ensure prior writes from other threads are visible
- `.release`: Ensure current writes become visible to other threads
- `.relaxed`: Only guarantees atomicity, no ordering constraints

### The Default: Sequential Consistency

By default, all operations use `.sequencialConsistency`, which provides the strongest memory ordering guarantee. This ensures:
- Operations appear in a consistent global order across all threads
- No surprising reorderings or stale reads
- Easiest to reason about correctness

**We strongly recommend using the default** unless you have a specific performance reason and deep understanding of memory ordering. Incorrect use of relaxed orderings can lead to subtle, hard-to-debug race conditions.

```swift
// Recommended: Use the default ordering
counter.fetchAdd(1)

// Advanced: Only specify ordering if you know what you're doing
counter.fetchAdd(1, order: .acquireAndRelease)
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
