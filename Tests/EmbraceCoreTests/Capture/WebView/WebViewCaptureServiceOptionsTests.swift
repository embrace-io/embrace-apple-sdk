//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    @testable import EmbraceCore
    import XCTest

    class WebViewCaptureServiceOptionsTests: XCTestCase {

        func test_defaults() {
            let options = WebViewCaptureService.Options()

            XCTAssertFalse(options.stripQueryParams)
            XCTAssertEqual(options.fragmentHandling, .keep)
        }

        func test_settingTheQueryOptionAloneLeavesTheFragmentHandlingUntouched() {
            let options = WebViewCaptureService.Options(stripQueryParams: true)

            XCTAssertTrue(options.stripQueryParams)
            XCTAssertEqual(options.fragmentHandling, .keep)
        }

        func test_settingTheFragmentHandlingAloneLeavesTheQueryOptionUntouched() {
            let options = WebViewCaptureService.Options(fragmentHandling: .remove)

            XCTAssertFalse(options.stripQueryParams)
            XCTAssertEqual(options.fragmentHandling, .remove)
        }
    }
#endif
