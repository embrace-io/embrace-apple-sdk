//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

// The macro plugin is built for the host, so these tests can only run on macOS. `canImport` alone
// isn't enough: Xcode 27 reports the plugin as importable in simulator builds even though its types
// aren't available there.
#if os(macOS) && canImport(EmbraceMacroPlugin)
    import SwiftSyntax
    import SwiftSyntaxBuilder
    import SwiftSyntaxMacroExpansion
    import SwiftSyntaxMacros
    import SwiftSyntaxMacrosTestSupport
    import XCTest

    import EmbraceMacroPlugin

    // Keyed by the attribute name as written in source, `@EmbraceTrace`.
    let macros: [String: Macro.Type] = [
        "EmbraceTrace": EmbraceTraceMacro.self
    ]

    final class EmbraceTraceMacroTests: XCTestCase {

        func testHappyPath_injectsTracingStubs() {
            assertMacroExpansion(
                """
                @EmbraceTrace
                struct Profile: View {
                    let name: String
                    var body: some View {
                        Text(name)
                    }
                }
                """,
                expandedSource: """
                    struct Profile: View {
                        let name: String
                        var body: some View {
                            Text(name)
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
                            // We have not yet found a way to call into the actual original
                            // `body`, so duplicate it here.

                                Text(name)
                        }

                        /// A container view that wraps the original body implementation.
                        ///
                        /// This internal container provides a clean way to reference the original
                        /// view hierarchy without creating reference cycles or complex dependencies.
                        /// It serves as an intermediary between the traced view and the original implementation.
                        struct _EmbraceBodyContainer: View {
                            /// Reference to the parent view instance
                            let view: Profile

                            /// The body of the container, which simply returns the original view implementation
                            var body: some View {
                                view._embraceOriginalBody
                            }
                        }

                        /// Redefines the `Body` typealias to use the traced view wrapper.
                        ///
                        /// This is a key part of the macro, as it changes the view's body type
                        /// to be wrapped in the `EmbraceTraceView` performance monitoring wrapper.
                        typealias Body = EmbraceTraceView<_EmbraceBodyContainer, Never>

                        /// Implementation of the `body` property for the `View` protocol.
                        ///
                        /// This property is marked with `@_implements` to indicate that it satisfies
                        /// the `body` requirement from the `View` protocol. It's marked with `@inline(never)`
                        /// to ensure that the trace boundary is preserved in release builds.
                        @_implements(View, body)
                        @inline(never)
                        @ViewBuilder
                        var _embraceTracedBody: Self.Body {
                            EmbraceTraceView("Profile") {
                                _EmbraceBodyContainer(view: self)
                            }
                        }
                    }
                    """,
                macros: macros
            )
        }

        /// `assertMacroExpansion` compares text only, and malformed syntax still prints the right text.
        /// Each generated declaration must also parse cleanly on its own.
        func test_generatedDeclarations_parseWithoutErrors() throws {
            let source: SourceFileSyntax = """
                @EmbraceTrace
                struct Profile: View {
                    var body: some View {
                        Text("profile")
                    }
                }
                """
            let structDecl = try XCTUnwrap(source.statements.first?.item.as(StructDeclSyntax.self))
            let attribute = try XCTUnwrap(structDecl.attributes.first?.as(AttributeSyntax.self))

            let declarations = try EmbraceTraceMacro.expansion(
                of: attribute,
                providingMembersOf: structDecl,
                conformingTo: [],
                in: BasicMacroExpansionContext()
            )

            XCTAssertEqual(declarations.count, 4)
            for declaration in declarations {
                XCTAssertFalse(declaration.hasError, "generated declaration has syntax errors:\n\(declaration)")
            }
        }

        func test_appliedToClass_reportsNotStruct() {
            assertMacroExpansion(
                """
                @EmbraceTrace
                class Profile: View {
                    var body: some View {
                        Text("profile")
                    }
                }
                """,
                expandedSource: """
                    class Profile: View {
                        var body: some View {
                            Text("profile")
                        }
                    }
                    """,
                diagnostics: [
                    DiagnosticSpec(message: "EmbraceTrace can only be applied to structs", line: 1, column: 1)
                ],
                macros: macros
            )
        }

        func test_structNotConformingToView_reportsNotView() {
            assertMacroExpansion(
                """
                @EmbraceTrace
                struct Profile {
                    var body: some View {
                        Text("profile")
                    }
                }
                """,
                expandedSource: """
                    struct Profile {
                        var body: some View {
                            Text("profile")
                        }
                    }
                    """,
                diagnostics: [
                    DiagnosticSpec(message: "Struct must conform to View to use EmbraceTrace", line: 1, column: 1)
                ],
                macros: macros
            )
        }

        func test_qualifiedSwiftUIView_expands() {
            assertMacroExpansion(
                """
                @EmbraceTrace
                struct Profile: SwiftUI.View {
                    var body: some View {
                        Text("profile")
                    }
                }
                """,
                expandedSource: """
                    struct Profile: SwiftUI.View {
                        var body: some View {
                            Text("profile")
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
                            // We have not yet found a way to call into the actual original
                            // `body`, so duplicate it here.

                                Text("profile")
                        }

                        /// A container view that wraps the original body implementation.
                        ///
                        /// This internal container provides a clean way to reference the original
                        /// view hierarchy without creating reference cycles or complex dependencies.
                        /// It serves as an intermediary between the traced view and the original implementation.
                        struct _EmbraceBodyContainer: View {
                            /// Reference to the parent view instance
                            let view: Profile

                            /// The body of the container, which simply returns the original view implementation
                            var body: some View {
                                view._embraceOriginalBody
                            }
                        }

                        /// Redefines the `Body` typealias to use the traced view wrapper.
                        ///
                        /// This is a key part of the macro, as it changes the view's body type
                        /// to be wrapped in the `EmbraceTraceView` performance monitoring wrapper.
                        typealias Body = EmbraceTraceView<_EmbraceBodyContainer, Never>

                        /// Implementation of the `body` property for the `View` protocol.
                        ///
                        /// This property is marked with `@_implements` to indicate that it satisfies
                        /// the `body` requirement from the `View` protocol. It's marked with `@inline(never)`
                        /// to ensure that the trace boundary is preserved in release builds.
                        @_implements(View, body)
                        @inline(never)
                        @ViewBuilder
                        var _embraceTracedBody: Self.Body {
                            EmbraceTraceView("Profile") {
                                _EmbraceBodyContainer(view: self)
                            }
                        }
                    }
                    """,
                macros: macros
            )
        }

        func test_viewWithoutBody_reportsNoBody() {
            assertMacroExpansion(
                """
                @EmbraceTrace
                struct Profile: View {
                    let name: String
                }
                """,
                expandedSource: """
                    struct Profile: View {
                        let name: String
                    }
                    """,
                diagnostics: [
                    DiagnosticSpec(message: "Struct must have a `body` property to use EmbraceTrace", line: 1, column: 1)
                ],
                macros: macros
            )
        }

        func test_storedBody_reportsNoAccessorBlock() {
            assertMacroExpansion(
                """
                @EmbraceTrace
                struct Profile: View {
                    var body = Text("profile")
                }
                """,
                expandedSource: """
                    struct Profile: View {
                        var body = Text("profile")
                    }
                    """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "The `body` property must have an accessor block to use EmbraceTrace", line: 1, column: 1)
                ],
                macros: macros
            )
        }
    }
#endif
