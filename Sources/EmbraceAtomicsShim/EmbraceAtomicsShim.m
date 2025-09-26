//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#include "EmbraceAtomicsShim.h"

#define EMB_DEFINE_ATOMIC_TYPE(TYPE, NAME)                                                                          \
    void emb_atomic_##NAME##_init(emb_atomic_##NAME##_t *a, TYPE value)                                             \
    {                                                                                                               \
        atomic_store_explicit(&a->v, value, memory_order_relaxed);                                                  \
    }                                                                                                               \
                                                                                                                    \
    TYPE emb_atomic_##NAME##_load(const emb_atomic_##NAME##_t *a, EMBAtomicMemoryOrder order)                       \
    {                                                                                                               \
        return atomic_load_explicit(&a->v, (memory_order)order);                                                    \
    }                                                                                                               \
                                                                                                                    \
    void emb_atomic_##NAME##_store(emb_atomic_##NAME##_t *a, TYPE value, EMBAtomicMemoryOrder order)                \
    {                                                                                                               \
        atomic_store_explicit(&a->v, value, (memory_order)order);                                                   \
    }                                                                                                               \
                                                                                                                    \
    TYPE emb_atomic_##NAME##_exchange(emb_atomic_##NAME##_t *a, TYPE value, EMBAtomicMemoryOrder order)             \
    {                                                                                                               \
        return atomic_exchange_explicit(&a->v, value, (memory_order)order);                                         \
    }                                                                                                               \
                                                                                                                    \
    bool emb_atomic_##NAME##_compare_exchange(emb_atomic_##NAME##_t *a, TYPE *expected, TYPE desired,               \
                                              EMBAtomicMemoryOrder successOrder, EMBAtomicMemoryOrder failureOrder) \
    {                                                                                                               \
        return atomic_compare_exchange_strong_explicit(&a->v, expected, desired, (memory_order)successOrder,        \
                                                       (memory_order)failureOrder);                                 \
    }                                                                                                               \
                                                                                                                    \
    TYPE emb_atomic_##NAME##_fetch_add(emb_atomic_##NAME##_t *a, TYPE delta, EMBAtomicMemoryOrder order)            \
    {                                                                                                               \
        return atomic_fetch_add_explicit(&a->v, delta, (memory_order)order);                                        \
    }                                                                                                               \
                                                                                                                    \
    TYPE emb_atomic_##NAME##_fetch_sub(emb_atomic_##NAME##_t *a, TYPE delta, EMBAtomicMemoryOrder order)            \
    {                                                                                                               \
        return atomic_fetch_sub_explicit(&a->v, delta, (memory_order)order);                                        \
    }

EMB_DEFINE_ATOMIC_TYPE(int8_t, int8)
EMB_DEFINE_ATOMIC_TYPE(int16_t, int16)
EMB_DEFINE_ATOMIC_TYPE(int32_t, int32)
EMB_DEFINE_ATOMIC_TYPE(int64_t, int64)

EMB_DEFINE_ATOMIC_TYPE(uint8_t, uint8)
EMB_DEFINE_ATOMIC_TYPE(uint16_t, uint16)
EMB_DEFINE_ATOMIC_TYPE(uint32_t, uint32)
EMB_DEFINE_ATOMIC_TYPE(uint64_t, uint64)

EMB_DEFINE_ATOMIC_TYPE(bool, bool)
