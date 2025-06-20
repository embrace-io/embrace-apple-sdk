//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import EmbraceIO

#if canImport(EmbraceMacroPlugin)
import EmbraceMacroPlugin

let macros: [String: Macro.Type] = [
    "embraceTrace": EmbraceTraceMacro.self
]
#endif

final class EmbraceTraceMacroTests: XCTestCase {

    func testHappyPath_injectsTracingStubs() throws {
#if canImport(EmbraceMacroPlugin)
        // can't get this working in a reliable way yet.
        /*
        let source = """
        import EmbraceIO
        import EmbraceTrace
        
        @EmbraceTrace
        struct MyView: View {
            var body: some View {
                Text("Hello")
            }
        }
        """
        
        let expected = """
        struct MyView: View {
            var body: some View {
                Text("Hello")
            }
        
            // @EmbraceTrace
            // This is your new `body`. It's the same as you declared above.
            // The macro adds the `embraceTrace` view modifier to it
            // which will instrument this View for you.
            // Inspired by https://github.com/SwiftUIX/SwiftUIX
        
            /// A private duplicate of the original `body` property.
            ///
            /// This property contains the exact same implementation as the original `body`,
            /// allowing the macro to preserve the original view hierarchy while still
            /// injecting performance tracing.
            private var _embraceOriginalBody: some View {
                Text("Hello")
            }
        
            /// A container view that wraps the original body implementation.
            ///
            /// This internal container provides a clean way to reference the original
            /// view hierarchy without creating reference cycles or complex dependencies.
            /// It serves as an intermediary between the traced view and the original implementation.
            struct _EmbraceBodyContainer: View {
                /// Reference to the parent view instance
                let view: MyView
        
                /// The body of the container, which simply returns the original view implementation
                var body: some View {
                    view._embraceOriginalBody
                }
            }
        
            /// Redefines the `Body` typealias to use the traced view wrapper.
            ///
            /// This is a key part of the macro, as it changes the view's body type
            /// to be wrapped in the `EmbraceTraceView` performance monitoring wrapper.
            typealias Body = EmbraceTraceView<_EmbraceBodyContainer>
        
            /// Implementation of the `body` property for the `View` protocol.
            ///
            /// This property is marked with `@_implements` to indicate that it satisfies
            /// the `body` requirement from the `View` protocol. It's marked with `@inline(never)`
            /// to ensure that the trace boundary is preserved in release builds.
            @_implements(View, body)
            @inline(never)
            @ViewBuilder
            var _embraceTracedBody: Self.Body {
                EmbraceTraceView("MyView") {
                    _EmbraceBodyContainer(view: self)
                }
            }
        }
        """
        
        assertMacroExpansion(
            source,
            expandedSource: expected,
            macros: macros
        )
         */
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
