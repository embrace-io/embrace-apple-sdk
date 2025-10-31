//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/**
 EMBThreadcrumb
 --------------
 Encodes a short message into a thread's call stack so it can be recovered later from crash reports.

 Concept
 - Map allowed characters to distinct function symbols and walk them to shape the stack.
 - Capture the stack at the end of the walk and return a pruned list of return addresses.

 Why
 - Recover identifiers (e.g., request IDs or breadcrumbs) from post-mortem stacks when higher-level
   context is unavailable.

 Usage
 - Create an instance of EMBThreadcrumb.
 - Call `-log:` with a message; only [0-9a-zA-Z_] characters are retained.
 - Receive an array of return addresses suitable for offline symbolication.

 Guarantees
 - Messages are sanitized and truncated to EMBThreadcrumbMaximumMessageLength.
 - Calls to `-log:` are serialized within an instance and complete synchronously.

 Limitations
 - Low-level diagnostic tool that depends on stack behavior and symbol visibility.
 - Not designed for concurrent `-log:` calls; use per-context instances if needed.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Maximum number of characters encoded into the stack (excess is truncated).
FOUNDATION_EXTERN NSInteger const EMBThreadcrumbMaximumMessageLength NS_SWIFT_NAME(EmbraceThreadcrumbMaximumMessageLength);

/**
 A utility that imprints a sanitized message into a dedicated worker thread's call stack and returns a
 pruned stack trace for later symbolication. Only [0-9a-zA-Z_] characters are encoded.
 */
NS_SWIFT_NAME(EmbraceThreadcrumb)
@interface EMBThreadcrumb : NSObject

/**
 Synchronously imprint the message and return a pruned stack trace.

 @param message Input text; only [0-9a-zA-Z_] characters are retained, others are stripped.
 @return Array of return addresses suitable for offline symbolication.

 Threading: Thread-safe; calls are serialized within an instance.
 Performance: Blocks the caller briefly until capture completes.
 Notes: Messages longer than EMBThreadcrumbMaximumMessageLength are truncated after sanitization.
 */
- (NSArray<NSNumber *> *)log:(NSString *)message;

@end

NS_ASSUME_NONNULL_END

