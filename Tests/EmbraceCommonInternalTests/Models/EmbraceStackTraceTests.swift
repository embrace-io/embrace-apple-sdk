//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceSemantics


class EmbraceStackTraceTests: XCTestCase {
    // MARK:  - Overall behaviour

    func test_init_withEmptyFramesShouldntThrow() {
        XCTAssertNoThrow(try EmbraceStackTrace(frames: []))
    }

    func test_init_withRandomFramesShouldThrow() {
        XCTAssertThrowsError(try EmbraceStackTrace(frames: [UUID().uuidString])) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .invalidFormat)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }

    func test_init_shouldBeAbleToBeGeneratedWithThreadCallStackAndKeepInformation() throws {
        let threadStackTrace = Thread.callStackSymbols
        // Implicit `XCTAssertNoThrow`
        let embraceStackTrace = try EmbraceStackTrace(frames: Thread.callStackSymbols)
        XCTAssertEqual(embraceStackTrace.frames.count, threadStackTrace.count)
    }

    func test_init_withCustomStackTrace_shouldBeAbleToBeGeneratedAndKeepInformation() throws {
        // Thread.callStackSymbols from other platform (e.g. Playgrounds app)
        let customStackTrace = [
            "0   Page_Contents                       0x000000010af45dec main + 136",
            "1   ExecutionExtension                  0x00000001002a7e24 ExecutionExtension + 32292",
            "2   CoreFoundation                      0x000000018a965070 __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__ + 28",
            "3   CoreFoundation                      0x000000018a964f84 __CFRunLoopDoBlocks + 356",
            "4   CoreFoundation                      0x000000018a963ddc __CFRunLoopRun + 848",
            "5   CoreFoundation                      0x000000018a963434 CFRunLoopRunSpecific + 608",
            "6   HIToolbox                           0x000000019510d19c RunCurrentEventLoopInMode + 292",
            "7   HIToolbox                           0x000000019510cfd8 ReceiveNextEventCommon + 648",
            "8   HIToolbox                           0x000000019510cd30 _BlockUntilNextEventMatchingListInModeWithFilter + 76",
            "9   AppKit                              0x000000018e1c2cc8 _DPSNextEvent + 660",
            "10  AppKit                              0x000000018e9b94d0 -[NSApplication(NSEventRouting) _nextEventMatchingEventMask:untilDate:inMode:dequeue:] + 700",
            "11  ViewBridge                          0x00000001930cc6dc __77-[NSViewServiceApplication vbNextEventMatchingMask:untilDate:inMode:dequeue:]_block_invoke + 136",
            "12  ViewBridge                          0x00000001930cc43c -[NSViewServiceApplication _withToxicEventMonitorPerform:] + 152",
            "13  ViewBridge                          0x00000001930cc63c -[NSViewServiceApplication vbNextEventMatchingMask:untilDate:inMode:dequeue:] + 168",
            "14  ViewBridge                          0x00000001930b89c0 -[NSViewServiceApplication nextEventMatchingMask:untilDate:inMode:dequeue:] + 100",
            "15  AppKit                              0x000000018e1b5ffc -[NSApplication run] + 476",
            "16  AppKit                              0x000000018e18d240 NSApplicationMain + 880",
            "17  AppKit                              0x000000018e3e0654 +[NSWindow _savedFrameFromString:] + 0",
            "18  UIKitMacHelper                      0x00000001a3c41f50 UINSApplicationMain + 972",
            "19  UIKitCore                           0x00000001b9e197bc UIApplicationMain + 148",
            "20  libxpc.dylib                        0x000000018a5ab870 _xpc_objc_uimain + 224",
            "21  libxpc.dylib                        0x000000018a59d2d0 _xpc_objc_main + 276",
            "22  libxpc.dylib                        0x000000018a5ace58 _xpc_main + 324",
            "23  libxpc.dylib                        0x000000018a59d014 _xpc_copy_xpcservice_dictionary + 0",
            "24  Foundation                          0x000000018bab6048 +[NSXPCListener serviceListener] + 0",
            "25  PlugInKit                           0x0000000198ccddb0 pkIsServiceAccount + 35664",
            "26  PlugInKit                           0x0000000198ccdc20 pkIsServiceAccount + 35264",
            "27  PlugInKit                           0x0000000198ccd88c pkIsServiceAccount + 34348",
            "28  PlugInKit                           0x0000000198cce180 pkIsServiceAccount + 36640",
            "29  ExtensionFoundation                 0x00000001e6485280 EXExtensionMain + 304",
            "30  Foundation                          0x000000018bb13668 NSExtensionMain + 204",
            "31  dyld                                0x000000018a4fb154 start + 2476"
        ]
        let embraceStackTrace = try EmbraceStackTrace(frames: customStackTrace)
        XCTAssertEqual(embraceStackTrace.frames.count, customStackTrace.count)
    }

    func test_init_ifOneFrameIsInvalid_shouldThrow() {
        let invalidStackTrace = [
            "0   Page_Contents                       0x000000010af45dec main + 136",  // valid frame
            "a",  // invalid frame
            "2   CoreFoundation                      0x000000018a965070 __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__ + 28"  // valid frame
        ]
        XCTAssertThrowsError(try EmbraceStackTrace(frames: invalidStackTrace)) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .invalidFormat)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }

    func test_initWithHugeStackTrace_shouldTrimToTwoHundredFrames() throws {
        let stackTrace = try EmbraceStackTrace(
            frames: generateRandomStackFrames(numberOfFrames: .random(in: 201...10000)))
        XCTAssertEqual(stackTrace.frames.count, 200)
        XCTAssertTrue(stackTrace.frames.first!.starts(with: "0"))
        XCTAssertTrue(stackTrace.frames.last!.starts(with: "199"))
    }

    // MARK: - Regex

    func test_stackFrame_shouldStartWithNumber() {
        let invalidFrame = "   EmbraceApp    0x0000000001234abc  -[MyClass myMethod] + 48"
        XCTAssertThrowsError(try EmbraceStackTrace(frames: [invalidFrame])) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .invalidFormat)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }

    func test_stackFrame_shouldHaveSpaceAfterFrameNumber() {
        let invalidFrame = "0EmbraceApp    0x0000000001234abc  -[MyClass myMethod] + 48"
        XCTAssertThrowsError(try EmbraceStackTrace(frames: [invalidFrame])) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .invalidFormat)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }

    func test_stackFrame_shouldContainModuleName() {
        let invalidFrame = "0   0x0000000001234abc  -[MyClass myMethod] + 48"
        XCTAssertThrowsError(try EmbraceStackTrace(frames: [invalidFrame])) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .invalidFormat)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }

    func test_stackFrame_shouldAllowSpacesInModuleName() {
        let validFrame = "0   Embrace SDK    0x0000000001234abc  -[MyClass myMethod] + 48"
        XCTAssertNoThrow(try EmbraceStackTrace(frames: [validFrame]))
    }

    func test_stackFrame_shouldAllowUnicodeCharsInModuleName() {
        let validFrame = "0   xx    0x0000000001234abc  -[MyClass myMethod] + 48"
        XCTAssertNoThrow(try EmbraceStackTrace(frames: [validFrame]))
    }

    func test_stackFrame_shouldHaveSpaceBeforeMemoryAddress() {
        let invalidFrame = "0   EmbraceApp0x0000000001234abc  -[MyClass myMethod] + 48"
        XCTAssertThrowsError(try EmbraceStackTrace(frames: [invalidFrame])) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .invalidFormat)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }

    func test_stackFrame_shouldHaveHexAddress() {
        let invalidFrame = "0   EmbraceApp    1234abc  -[MyClass myMethod] + 48"
        XCTAssertThrowsError(try EmbraceStackTrace(frames: [invalidFrame])) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .invalidFormat)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }

    func test_stackFrame_shouldHaveSpaceBeforeSymbol() {
        let invalidFrame = "0   EmbraceApp    0x0000000001234abc-[MyClass myMethod] + 48"
        XCTAssertThrowsError(try EmbraceStackTrace(frames: [invalidFrame])) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .invalidFormat)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }

    func test_stackFrame_shouldHaveFunctionSymbol() {
        let invalidFrame = "0   EmbraceApp    0x0000000001234abc  "
        XCTAssertThrowsError(try EmbraceStackTrace(frames: [invalidFrame])) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .invalidFormat)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }

    func test_stackFrame_couldHaveSlideOffsetForSymbol() {
        let symbolWithSlideOffsetFrame = "0   EmbraceApp    0x0000000001234abc  + 48"
        let symbolWithoutSlideOffsetFrame = "0   EmbraceApp    0x0000000001234abc  + 48"
        XCTAssertNoThrow(try EmbraceStackTrace(frames: [symbolWithSlideOffsetFrame]))
        XCTAssertNoThrow(try EmbraceStackTrace(frames: [symbolWithoutSlideOffsetFrame]))
    }

    func test_stackFrame_cantHaveMoreThanTenThousandCharacters() {
        let longFrame = String(repeating: "A", count: 10001)
        XCTAssertThrowsError(try EmbraceStackTrace(frames: [longFrame])) { error in
            if let error = error as? EmbraceStackTraceError {
                XCTAssertTrue(error == .frameIsTooLong)
            } else {
                XCTFail("Error should be `EmbraceStackTraceError.invalidFormat`")
            }
        }
    }
}

extension EmbraceStackTraceTests {
    fileprivate func generateRandomStackFrames(numberOfFrames: Int = 30) -> [String] {
        return (0..<numberOfFrames).map { index in
            let randomHex = String(format: "0x%08x", Int.random(in: 0x1000_0000...0xFFFF_FFFF))
            let randomClass = UUID().uuidString
            let randomMethod = UUID().uuidString

            return "\(index) BrandGame \(randomHex) [\(randomClass) \(randomMethod)] + 48"
        }
    }
}
