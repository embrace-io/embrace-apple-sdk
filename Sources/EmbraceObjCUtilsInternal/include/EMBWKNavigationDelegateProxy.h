//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    

#import <Foundation/Foundation.h>
#if __has_include(<WebKit/WebKit.h>)
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMBWKNavigationDelegateProxy: NSProxy <WKNavigationDelegate>

@property (nonatomic, weak, nullable) id<WKNavigationDelegate> originalDelegate;

/// callback triggered the webview loads an url or errors
@property (copy, nullable) void (^callback)(NSURL * _Nullable, NSInteger);

- (instancetype)initWithOriginalDelegate:(id<WKNavigationDelegate> _Nullable)originalDelegate
                               callback:(void (^ _Nullable)(NSURL * _Nullable, NSInteger))callback;

@end

NS_ASSUME_NONNULL_END

#endif
