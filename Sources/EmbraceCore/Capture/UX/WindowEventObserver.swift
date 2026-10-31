//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import UIKit
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

    /// Fans out every `UIWindow.sendEvent(_:)` to its handlers, so services that need window events share
    /// one swizzle and work whether or not the others are enabled.
    ///
    /// The swizzle is installed when the first handler is added and is never removed.
    final class WindowEventObserver {

        static let shared = WindowEventObserver()

        struct Token: Equatable {
            fileprivate let id: Int
        }

        /// Adds a handler, called on main for each event before the window handles it. Installs the swizzle
        /// on first use.
        ///
        /// - Throws: If the swizzle can't be installed. The handler is not added, and the next call retries.
        @discardableResult
        func add(_ handler: @escaping (UIEvent) -> Void) throws -> Token {
            try data.withLock { data in
                if data.swizzler == nil {
                    let swizzler = UIWindowSendEventSwizzler()
                    swizzler.onEvent = { [weak self] event in
                        self?.dispatch(event)
                    }
                    try swizzler.install()
                    data.swizzler = swizzler
                }

                let token = Token(id: data.nextId)
                data.nextId += 1
                data.handlers.append((token, handler))
                return token
            }
        }

        func remove(_ token: Token) {
            data.withLock { data in
                data.handlers.removeAll { $0.token == token }
            }
        }

        // MARK: - Private

        private struct MutableData {
            var swizzler: UIWindowSendEventSwizzler?
            var handlers: [(token: Token, handler: (UIEvent) -> Void)] = []
            var nextId = 0
        }

        private let data = EmbraceMutex(MutableData())

        /// Handlers run outside the lock, so they can add or remove handlers.
        private func dispatch(_ event: UIEvent) {
            let handlers = data.withLock { $0.handlers }
            for entry in handlers {
                entry.handler(event)
            }
        }
    }

    class UIWindowSendEventSwizzler: Swizzlable {
        typealias ImplementationType = @convention(c) (UIWindow, Selector, UIEvent) -> Void
        typealias BlockImplementationType = @convention(block) (UIWindow, UIEvent) -> Void
        static var selector: Selector = #selector(
            UIWindow.sendEvent(_:)
        )

        var baseClass: AnyClass = UIWindow.self

        var onEvent: ((UIEvent) -> Void)?

        func install() throws {
            try swizzleInstanceMethod { originalImplementation in
                { [weak self] uiWindow, uiEvent in
                    self?.onEvent?(uiEvent)
                    originalImplementation(uiWindow, UIWindowSendEventSwizzler.selector, uiEvent)
                }
            }
        }
    }

#endif
