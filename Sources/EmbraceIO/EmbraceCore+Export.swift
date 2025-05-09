//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

// DEV: Want to @_exported the EmbraceCore module so callers can:
//      ```
//      import EmbraceIO
//      ```
//
//      instead of:
//      ```
//      import EmbraceIO
//      import EmbraceCore
//      ```

#if !EMBRACE_COCOAPOD_BUILDING_SDK
@_exported import EmbraceCore
#endif
