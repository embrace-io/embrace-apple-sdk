//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#ifndef emb_sampler_h
#define emb_sampler_h

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque sampler handle.
typedef struct emb_sampler *emb_sampler_t;

/// Create a sampler. Returns NULL on failure.
emb_sampler_t emb_sampler_create(void);

/// Start sampling. Returns true on success.
bool emb_sampler_start(emb_sampler_t sampler);

/// Stop sampling.
void emb_sampler_stop(emb_sampler_t sampler);

/// Returns true if the sampler is currently running.
bool emb_sampler_is_running(emb_sampler_t sampler);

/// Destroy a sampler and release its resources.
void emb_sampler_destroy(emb_sampler_t sampler);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_sampler_h */
