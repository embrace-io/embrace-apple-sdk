//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceBugsnagTools
import XCTest

class EmbraceBugsnagToolsTests: XCTestCase {

    func takeStacktrace(of thread: pthread_t) -> [UInt] {

        let machThread = pthread_mach_thread_np(thread)
        
        let entries = 512
        var frames: [UInt] = Array(repeating: 0, count: 512)
        
        let entryCount = bsg_ksbt_backtraceThread(machThread, &frames, Int32(entries))
        
        return Array(frames.prefix(Int(entryCount)))
    }
    
    func test_bugsnagTools() {
        
        let expectation = XCTestExpectation()
        
        let thread = pthread_self()
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            let result = takeStacktrace(of: thread)
            XCTAssertFalse(result.isEmpty)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }
}
