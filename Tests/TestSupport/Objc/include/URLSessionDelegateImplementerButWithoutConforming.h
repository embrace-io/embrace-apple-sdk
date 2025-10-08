//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface URLSessionDelegateImplementerButWithoutConforming : NSObject <NSURLSessionDelegate>

@property(nonatomic, assign) BOOL didInvokeDidReceiveData;
@property(nonatomic, assign) BOOL didInvokeDidBecomeInvalidWithError;
@property(nonatomic, assign) BOOL didInvokeDidFinishCollectingMetrics;
@property(nonatomic, assign) BOOL didInvokedDidCompleteWithError;

@end

NS_ASSUME_NONNULL_END
