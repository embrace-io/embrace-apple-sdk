//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Creates an `EMBURLSessionLegacyDelegateProxy` directly, bypassing `EmbraceMakeURLSessionDelegateProxy`
/// (which uses a `dispatch_once` flag and always returns `NewProxy` in the default test environment).
///
/// Returns `id` — callers should cast to `EMBURLSessionDelegateProxy` or use as `AnyObject`.
FOUNDATION_EXPORT id MakeLegacyURLSessionDelegateProxy(id _Nullable delegate, id handler);

NS_ASSUME_NONNULL_END
