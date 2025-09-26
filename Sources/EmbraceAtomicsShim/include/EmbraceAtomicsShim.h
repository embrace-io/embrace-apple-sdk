//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <stdatomic.h>
#import <stdbool.h>
#import <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Use NS_ENUM so Swift gets a proper enum.
typedef NS_ENUM(uint8_t, EMBAtomicMemoryOrder) {
    EMBAtomicMemoryOrderRelaxed = memory_order_relaxed,
    EMBAtomicMemoryOrderConsume = memory_order_consume,
    EMBAtomicMemoryOrderAcquire = memory_order_acquire,
    EMBAtomicMemoryOrderRelease = memory_order_release,
    EMBAtomicMemoryOrderAcqRel = memory_order_acq_rel,
    EMBAtomicMemoryOrderSeqCst = memory_order_seq_cst,
};

// Macro to declare an atomic wrapper + API for a given type
#define EMB_DECLARE_ATOMIC_TYPE(TYPE, NAME)                                                                          \
    typedef struct {                                                                                                 \
        _Atomic(TYPE) v;                                                                                             \
    } emb_atomic_##NAME##_t;                                                                                         \
                                                                                                                     \
    void emb_atomic_##NAME##_init(emb_atomic_##NAME##_t *a, TYPE value);                                             \
    TYPE emb_atomic_##NAME##_load(const emb_atomic_##NAME##_t *a, EMBAtomicMemoryOrder order);                       \
    void emb_atomic_##NAME##_store(emb_atomic_##NAME##_t *a, TYPE value, EMBAtomicMemoryOrder order);                \
    TYPE emb_atomic_##NAME##_exchange(emb_atomic_##NAME##_t *a, TYPE value, EMBAtomicMemoryOrder order);             \
    bool emb_atomic_##NAME##_compare_exchange(emb_atomic_##NAME##_t *a, TYPE *expected, TYPE desired,                \
                                              EMBAtomicMemoryOrder successOrder, EMBAtomicMemoryOrder failureOrder); \
    TYPE emb_atomic_##NAME##_fetch_add(emb_atomic_##NAME##_t *a, TYPE delta, EMBAtomicMemoryOrder order);            \
    TYPE emb_atomic_##NAME##_fetch_sub(emb_atomic_##NAME##_t *a, TYPE delta, EMBAtomicMemoryOrder order);

EMB_DECLARE_ATOMIC_TYPE(int8_t, int8)
EMB_DECLARE_ATOMIC_TYPE(int16_t, int16)
EMB_DECLARE_ATOMIC_TYPE(int32_t, int32)
EMB_DECLARE_ATOMIC_TYPE(int64_t, int64)

EMB_DECLARE_ATOMIC_TYPE(uint8_t, uint8)
EMB_DECLARE_ATOMIC_TYPE(uint16_t, uint16)
EMB_DECLARE_ATOMIC_TYPE(uint32_t, uint32)
EMB_DECLARE_ATOMIC_TYPE(uint64_t, uint64)

EMB_DECLARE_ATOMIC_TYPE(bool, bool)

#ifdef __cplusplus
}
#endif
