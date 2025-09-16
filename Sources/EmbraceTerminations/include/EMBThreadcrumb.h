//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/**
 EMBThreadcrumb (EmbraceThreadcrumb) creates a distinctive stack shape by walking per-character functions
 to reliably capture a pruned stack for later symbolication.

 Usage:
 - Create an instance of EMBThreadcrumb.
 - Call -log: with an ASCII/underscore message.
 - Receive an array of return addresses representing the pruned stack.

 Threading notes:
 - Single-flight: one log at a time per instance.
 - The method is synchronous and blocks the caller until the stack is captured.

 Performance notes:
 - Lightweight implementation.
 - A background pthread is created once internally to facilitate stack capturing.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 EMBThreadcrumb creates a unique stack shape by imprinting a sanitized message into a background worker thread’s stack.
 It internally manages a dedicated background thread for this purpose.
 The message is sanitized to include only characters in [0-9a-zA-Z_] before imprinting into the thread’s stack.
 */
NS_SWIFT_NAME(EmbraceThreadcrumb)
@interface EMBThreadcrumb : NSObject

/**
 Synchronously imprints the provided message into a worker thread’s stack and returns a pruned stack trace.

 @param message A string message where only characters in [0-9a-zA-Z_] are retained; all other characters are stripped.
 @return An NSArray of NSNumber objects representing return addresses suitable for offline symbolication. Returns an
 empty array if the capture failed.

 Thread-safety: This method is not reentrant and must not be called concurrently on the same EMBThreadcrumb instance.
 Performance: This method blocks the caller until the capture completes, but completion is typically very fast.

 Swift name: Exposed as EmbraceThreadcrumb.log in Swift due to the NS_SWIFT_NAME on the class.
 */
- (NSArray<NSNumber *> *)log:(NSString *)message;

@end

NS_ASSUME_NONNULL_END

