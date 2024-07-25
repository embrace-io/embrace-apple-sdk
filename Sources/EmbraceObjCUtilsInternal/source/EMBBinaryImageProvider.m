//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
    

#import "EMBBinaryImageProvider.h"
#include <mach-o/dyld.h>
#include <dlfcn.h>

#pragma mark - C declarations

bool process_binary_image(const char * __unused name, const void *header, struct uuid_command *out_uuid, uintptr_t *out_baseaddr)
{
    uint32_t ncmds;
    const struct mach_header *header32 = (const struct mach_header *) header;
    const struct mach_header_64 *header64 = (const struct mach_header_64 *) header;

    struct load_command *cmd;

    /* Check for 32-bit/64-bit header and extract required values */
    switch (header32->magic) {
            /* 32-bit */
        case MH_MAGIC:
        case MH_CIGAM:
            ncmds = header32->ncmds;
            cmd = (struct load_command *) (header32 + 1);
            break;

            /* 64-bit */
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            ncmds = header64->ncmds;
            cmd = (struct load_command *) (header64 + 1);
            break;

        default:
            NSLog(@"Invalid Mach-O header magic value: %x", header32->magic);
            return false;
    }

    /* Compute the image size and search for a UUID */
    struct uuid_command *uuid = NULL;

    for (uint32_t i = 0; cmd != NULL && i < ncmds; i++) {
        /* DWARF dSYM UUID */
        if (cmd->cmd == LC_UUID && cmd->cmdsize == sizeof(struct uuid_command))
            uuid = (struct uuid_command *) cmd;

        cmd = (struct load_command *) ((uint8_t *) cmd + cmd->cmdsize);
    }

    /* Base address */
    uintptr_t base_addr;
    base_addr = (uintptr_t) header;

    *out_baseaddr = base_addr;
    if(out_uuid && uuid)
        memcpy(out_uuid, uuid, sizeof(struct uuid_command));

    return true;
}

#pragma mark - EMBBinaryImageManager implementation

@interface EMBBinaryImageProvider ()

@end

@implementation EMBBinaryImageProvider

#pragma mark - Initialization

- (instancetype)init
{
    self = [super init];
    return self;
}

- (void)binaryImageForAddress:(uintptr_t)ptr completion:(void (^)(NSString *path, NSString *uuid, NSNumber *baseAddress))completion
{
    Dl_info image_info;
    if (dladdr((const void *)ptr, &image_info) == 0) {
        NSLog(@"Could not get info for binary image.");
        return;
    }

    int i;
    struct uuid_command uuid = { 0 };
    uintptr_t baseaddr;
    char uuidstr[64] = { 0 };

    NSString *path = @"", *moduleUUID = @"";
    NSNumber *baseAddress = @(0);

    if (process_binary_image(image_info.dli_fname, (const void *) image_info.dli_fbase, &uuid, &baseaddr)) {
        for(i=0; i<16; i++) {
            char *buff = &uuidstr[2*i];
            snprintf(buff, sizeof(buff), "%02x", uuid.uuid[i]);
        }
        path = @(image_info.dli_fname);
        baseAddress = @(baseaddr);
        moduleUUID = @(uuidstr);
    } else {
        NSLog(@"Could not get UUID and base address for binary image %s. Skipping.", image_info.dli_fname);
    }
    completion(path, moduleUUID, baseAddress);
}

@end
