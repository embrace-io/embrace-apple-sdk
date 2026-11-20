//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import TestSupport
    import XCTest

    @testable import EmbraceCore

    /// Navigations reported to smoothness, which interrupt the open focal moment.
    final class UIViewControllerHandlerNavigationTests: XCTestCase {

        private var dataSource: MockUIViewControllerHandlerDataSource!
        private var handler: UIViewControllerHandler!
        private var isNavigation = true
        private var navigations = 0

        override func setUpWithError() throws {
            try super.setUpWithError()
            isNavigation = true
            navigations = 0
            dataSource = MockUIViewControllerHandlerDataSource()
            dataSource.instrumentFirstRender = false
            handler = UIViewControllerHandler(
                queue: MockQueue(),
                frameCountTotals: { nil },
                isNavigation: { [unowned self] _ in self.isNavigation },
                screenDidNavigate: { [unowned self] in self.navigations += 1 }
            )
            handler.dataSource = dataSource
        }

        override func tearDownWithError() throws {
            handler = nil
            dataSource = nil
            try super.tearDownWithError()
        }

        // MARK: - Reporting

        func test_navigationAppearing_isReported() {
            handler.notifyIfNavigation(MockViewController())

            XCTAssertEqual(navigations, 1)
        }

        func test_nonNavigationAppearing_isNotReported() {
            isNavigation = false

            handler.notifyIfNavigation(MockViewController())

            XCTAssertEqual(navigations, 0)
        }

        func test_blockedController_isNotReported() {
            dataSource.blockList = ViewControllerBlockList(types: [MockViewController.self])

            handler.notifyIfNavigation(MockViewController())

            XCTAssertEqual(navigations, 0)
        }

        func test_controllerOptedOut_isNotReported() {
            let vc = MockViewController()
            vc.shouldCaptureViewInEmbrace = false

            handler.notifyIfNavigation(vc)

            XCTAssertEqual(navigations, 0)
        }

        func test_serviceNotActive_isNotReported() {
            dataSource.serviceState = .paused

            handler.notifyIfNavigation(MockViewController())

            XCTAssertEqual(navigations, 0)
        }

        func test_viewDidAppearEnd_isNotReported() {
            // Reported from the `viewDidAppear` swizzle instead, so a first appearance isn't reported twice.
            handler.onViewDidAppearEnd(MockViewController())

            XCTAssertEqual(navigations, 0)
        }

        // MARK: - What counts as a navigation

        /// Puts `root` in a window and loads `vc`'s view into it.
        private func show(_ vc: UIViewController, in root: UIViewController) -> UIWindow {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
            window.rootViewController = root
            window.isHidden = false
            root.view.layoutIfNeeded()
            if vc.viewIfLoaded?.window == nil, vc !== root {
                root.view.addSubview(vc.view)
            }
            return window
        }

        private func isNavigation(_ vc: UIViewController, keyWindow: Bool = true) -> Bool {
            UIViewControllerHandler.isNavigation(vc, isKeyWindow: { _ in keyWindow })
        }

        func test_isNavigation_navigationChild() {
            let vc = UIViewController()
            let nav = UINavigationController(rootViewController: vc)
            let window = show(vc, in: nav)

            XCTAssertTrue(isNavigation(vc))
            withExtendedLifetime(window) {}
        }

        func test_isNavigation_tabChild() {
            let vc = UIViewController()
            let tabs = UITabBarController()
            tabs.viewControllers = [vc]
            let window = show(vc, in: tabs)

            XCTAssertTrue(isNavigation(vc))
            withExtendedLifetime(window) {}
        }

        func test_isNavigation_splitChild() {
            let vc = UIViewController()
            let split = UISplitViewController()
            split.viewControllers = [vc]
            let window = show(vc, in: split)

            XCTAssertTrue(isNavigation(vc))
            withExtendedLifetime(window) {}
        }

        func test_isNavigation_windowRoot() {
            let vc = UIViewController()
            let window = show(vc, in: vc)

            XCTAssertTrue(isNavigation(vc))
            withExtendedLifetime(window) {}
        }

        func test_isNavigation_presentedRoot() {
            let vc = PresentedViewController()
            vc.presenter = UIViewController()
            let window = show(vc, in: UIViewController())

            XCTAssertTrue(isNavigation(vc))
            withExtendedLifetime(window) {}
        }

        func test_isNavigation_embeddedChild_isNot() {
            let container = UIViewController()
            let vc = UIViewController()
            container.addChild(vc)
            let window = show(vc, in: container)

            XCTAssertFalse(isNavigation(vc))
            withExtendedLifetime(window) {}
        }

        func test_isNavigation_notInKeyWindow_isNot() {
            let vc = UIViewController()
            let window = show(vc, in: vc)

            XCTAssertFalse(isNavigation(vc, keyWindow: false))
            withExtendedLifetime(window) {}
        }

        func test_isNavigation_notInWindow_isNot() {
            XCTAssertFalse(isNavigation(UIViewController()))
        }
    }

    private final class PresentedViewController: UIViewController {
        var presenter: UIViewController?
        override var presentingViewController: UIViewController? { presenter }
    }

#endif
