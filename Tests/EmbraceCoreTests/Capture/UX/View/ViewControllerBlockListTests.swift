//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
#if canImport(UIKit) && !os(watchOS)

import Foundation
import XCTest
import SwiftUI
@testable import EmbraceCore


class ViewControllerBlockListTests: XCTestCase {

    func test_isBlocked_byName() {
        // given a block list with names
        let blockList = ViewControllerBlockList(names: ["Test"])

        // when checking if a vc should be blocked
        let vc = TestViewController()
        let blocked = blockList.isBlocked(viewController: vc)

        // then it correctly blocks it
        XCTAssertTrue(blocked)
    }

    func test_isBlocked_byType() {
        // given a block list with types
        let blockList = ViewControllerBlockList(types: [TestViewController.self])

        // when checking if a vc should be blocked
        let vc = TestViewController()
        let blocked = blockList.isBlocked(viewController: vc)

        // then it correctly blocks it
        XCTAssertTrue(blocked)
    }

    func test_hostingController_byName() {
        // given a block list blocking hosting controllers
        let blockList = ViewControllerBlockList(blockHostingControllers: true)

        // when checking if a non hosting controller vc should be blocked
        let vc = TestFakeHostingController()
        let blocked = blockList.isBlocked(viewController: vc)

        // then it correctly doesn't block it
        XCTAssertFalse(blocked)
    }

    func test_hostingController_byType() {
        // given a block list blocking hosting controllers
        let blockList = ViewControllerBlockList(blockHostingControllers: true)

        // when checking if a vc should be blocked
        let vc = TestHostingSubclassController(rootView: TestView())
        let blocked = blockList.isBlocked(viewController: vc)

        // then it correctly blocks it
        XCTAssertTrue(blocked)
    }

    func test_hostingController_byParent() {
        // given a block list blocking hosting controllers
        let blockList = ViewControllerBlockList(blockHostingControllers: true)

        // when checking if a vc should be blocked
        let parent = TestHostingSubclassController(rootView: TestView())
        let vc = TestViewController()
        parent.addChild(vc)
        let blocked = blockList.isBlocked(viewController: vc)

        // then it correctly blocks it
        XCTAssertTrue(blocked)
    }
}

// MARK: - Fake classes

class TestViewController: UIViewController {

}

class TestFakeHostingController: UIViewController {

}

struct TestView: View {
    var body: some View { EmptyView() }
}

class TestHostingSubclassController: UIHostingController<TestView> {

}

#endif
