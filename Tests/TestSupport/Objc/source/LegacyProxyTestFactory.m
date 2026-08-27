//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "LegacyProxyTestFactory.h"
#import "EMBURLSessionDelegateProtocol.h"

id MakeLegacyURLSessionDelegateProxy(id delegate, id handler)
{
    // EMBURLSessionLegacyDelegateProxy is not in the public module headers, so we look it up
    // by name. initWithDelegate:handler: is declared in EMBURLSessionDelegateProxy protocol.
    Class klass = NSClassFromString(@"EMBURLSessionLegacyDelegateProxy");
    return [(id<EMBURLSessionDelegateProxy>)[klass alloc] initWithDelegate:delegate handler:handler];
}
