//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_sampler.h"

#if !TARGET_OS_WATCH

emb_sampler_t emb_sampler_create(void)
{
    return NULL;
}

bool emb_sampler_start(emb_sampler_t sampler)
{
    (void)sampler;
    return false;
}

void emb_sampler_stop(emb_sampler_t sampler)
{
    (void)sampler;
}

bool emb_sampler_is_running(emb_sampler_t sampler)
{
    (void)sampler;
    return false;
}

void emb_sampler_destroy(emb_sampler_t sampler)
{
    (void)sampler;
}

#endif /* !TARGET_OS_WATCH */
