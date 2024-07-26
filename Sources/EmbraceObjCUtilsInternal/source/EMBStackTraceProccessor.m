//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBStackTraceProccessor.h"
#import "EMBBinaryImageProvider.h"

static NSString *const EMBStackTraceModuleNameKey = @"m";
static NSString *const EMBStackTraceModulePathKey = @"p";
static NSString *const EMBStackTraceModuleOffsetKey = @"o";
static NSString *const EMBStackTraceModuleUUIDKey = @"u";
static NSString *const EMBStackTraceInstructionAddressKey = @"a";
static NSString *const EMBStackTraceSymbolNameKey = @"s";
static NSString *const EMBStackTraceSymbolOffsetKey = @"so";

@implementation EMBStackTraceProccessor

+ (NSArray<NSDictionary<NSString *, id> *> *)processStackTrace:(NSArray<NSString *> *)rawStackTrace
{
    // The raw stack trace is an array of stringified frames created by Apple
    // The format is human readable, and we wish to parse it into a machine readable structure
    // on the client.
    NSMutableArray *augmentedStackReturnAddresses = [NSMutableArray array];
    
    // Process each frame
    for (NSString *line in rawStackTrace) {
        // we'll be using start and current to delimit substrings found in the frame's line.
        int start = 0;
        int current = 0;
        // Find the first space, things before this represent the frame number which we don't need
        // but we must find in order to remove it from the module name.
        for (int i = start; i < line.length; i++) {
            if ([line characterAtIndex:i] == ' ') {
                break;
            }
            current++;
        }
        start = current;
        // Module names can have spaces in them, multiple spaces even.
        // We're defining a module name as having at least one non-space character, ending with at least 1 space and followed by 0x.
        // This is not perfect.  For example I could name my module "embrace 0xawesome module" and our parsing would break.
        bool foundOneNonSpace = false;
        bool foundOneSpace = false;
        for (int i = start; i < line.length; i++) {
            // We must find at least 1 non-space character, modules have to have 1 character at least in their name
            if ([line characterAtIndex:i] != ' ' && foundOneNonSpace == false) {
                foundOneNonSpace = true;
            // We must then find one space at least, we may find multiple and that is ok, but there must be at least 1 to mark the end of the module name
            } else if ([line characterAtIndex:i] == ' ' && foundOneNonSpace == true) {
                foundOneSpace = true;
            }
            // Having found one non-space and one space we can now start hunting for the address which will start with '0x'
            if (i != line.length - 1 && [line characterAtIndex:i] == '0' && [line characterAtIndex:i+1] == 'x' && foundOneNonSpace == true && foundOneSpace == true) {
                break;
            }
            current ++;
        }
        
        NSString *moduleName = [line substringWithRange:NSMakeRange(start, current-start)];
        moduleName = [moduleName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        start = current;
        // The address never contains a space, so the first space we find after the address marks the end of the address.
        for (int i = start; i < line.length; i++) {
            if ([line characterAtIndex:i] == ' ') {
                break;
            }
            current++;
        }
        NSString *address = [line substringWithRange:NSMakeRange(start, current-start)];
        // The remaining string contains the symbol and the slide offset
        NSString *remaining = [line substringWithRange:NSMakeRange(current, line.length-current)];
        // Slide is always prefixed with ' + ' if it exists, so split on that.
        NSArray *components = [remaining componentsSeparatedByString:@" + "];
        // The first part must exist and must be the symbol or this wasn't a valid frame.
        NSString *symbol = components[0];
        symbol = [symbol stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *slideOffset;
        // slide may not exist, if it does --> record id.
        if (components.count > 1) {
            slideOffset = components[1];
        }
        
        // Find the module in our collection using the name.  This gives the path and UUID
        // remove 0x prefix and parse address into a long
        unsigned long long ptr = 0;
        [[NSScanner scannerWithString:address] scanHexLongLong:&ptr];
        __block NSString *modulePath;
        __block NSString *moduleUUID;
        __block NSNumber *addr;
        [[EMBBinaryImageProvider new] binaryImageForAddress:ptr
                                                    completion:^(NSString * _Nonnull path,
                                                                 NSString * _Nonnull uuid,
                                                                 NSNumber * _Nonnull baseAddress) {
            modulePath = path;
            moduleUUID = [uuid uppercaseString];
            addr = baseAddress;
        }];
        
        // Rebase the address to the module's load address giving us a proper module-offset address.
        NSNumber *instructionOffset = [NSNumber numberWithLongLong:strtoull([address UTF8String], NULL, 16)];
        NSNumber *moduleOffset = @(instructionOffset.integerValue - addr.integerValue);
        
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        dictionary[EMBStackTraceModuleNameKey] = moduleName ?: @"";
        dictionary[EMBStackTraceModulePathKey] = modulePath ?: @"";
        dictionary[EMBStackTraceModuleOffsetKey] = moduleOffset ?: @(-1);
        dictionary[EMBStackTraceModuleUUIDKey] = moduleUUID ?: @"";
        dictionary[EMBStackTraceInstructionAddressKey] = address ?: @"";
        dictionary[EMBStackTraceSymbolNameKey] = symbol ?: @"";
        dictionary[EMBStackTraceSymbolOffsetKey] = @(slideOffset.intValue) ?: @(-1);
        [augmentedStackReturnAddresses addObject:dictionary];
    }
    
    return augmentedStackReturnAddresses;
}

@end
