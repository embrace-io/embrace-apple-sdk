//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A SwiftSyntax macro that automatically instruments SwiftUI `View` bodies with
/// Embrace performance tracing.
///
/// When applied to a struct conforming to `View`, this macro generates a private
/// duplicate of the `body`, wraps it in an internal container view, and rebinds
/// the `Body` typealias to `EmbraceTraceView<Container>`, inserting tracing hooks.
///
/// Usage:
/// ```
/// @EmbraceTrace
/// struct MyView: View {
///     var body: some View {
///         Text("Hello World")
///     }
/// }
/// ```
///
/// This automatically instruments the view for performance monitoring without manual tracing code.
public struct EmbraceTraceMacro {}

/// Conformance to `MemberMacro` to provide additional declarations for the
/// annotated struct.
///
/// This protocol method is invoked at compile time to generate the helper
/// properties, types, and typealias needed to wrap and trace the original body.
extension EmbraceTraceMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Validate that the macro is applied to a struct declaration
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node, message: EmbraceTraceDiagnostic(message: "EmbraceTrace can only be applied to structs"))
            )
            throw EmbraceMacroError.notStruct
        }

        // Check that the struct conforms to SwiftUI's View protocol
        let inheritsView =
            structDecl.inheritanceClause?.inheritedTypes.contains {
                if let identType = $0.type.as(IdentifierTypeSyntax.self) {
                    return identType.name.text == "View"
                }
                // Handle qualified types like SwiftUI.View as well
                if let memberType = $0.type.as(MemberTypeSyntax.self),
                    let baseType = memberType.baseType.as(IdentifierTypeSyntax.self),
                    baseType.name.text == "SwiftUI",
                    memberType.name.text == "View" {
                    return true
                }
                return false
            } ?? false
        guard inheritsView else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: EmbraceTraceDiagnostic(message: "Struct must conform to View to use EmbraceTrace")))
            throw EmbraceMacroError.notConformingToView
        }

        // Find the 'body' property in the struct's members
        let viewBodyVariable: VariableDeclSyntax? = structDecl.memberBlock.members.lazy
            .compactMap({ $0.decl.as(VariableDeclSyntax.self) })
            .filter {
                $0.bindings.first?
                    .pattern
                    .as(IdentifierPatternSyntax.self)?
                    .identifier.text == "body"
            }
            .first

        guard let viewBodyVariable else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: EmbraceTraceDiagnostic(message: "Struct must have a `body` property to use EmbraceTrace")))
            throw EmbraceMacroError.noBody
        }

        // Ensure the 'body' property has an accessor block for computed body
        guard let declaration = viewBodyVariable.bindings.first?.accessorBlock?.accessors._syntaxNode else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: EmbraceTraceDiagnostic(
                        message: "The `body` property must have an accessor block to use EmbraceTrace")))
            throw EmbraceMacroError.noBody
        }

        // Construct the injected declarations: original body, container view, and traced body
        let syntax = DeclSyntax(
            """

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
            \(raw: declaration.description)
            }

            /// A container view that wraps the original body implementation.
            ///
            /// This internal container provides a clean way to reference the original
            /// view hierarchy without creating reference cycles or complex dependencies.
            /// It serves as an intermediary between the traced view and the original implementation.
            struct _EmbraceBodyContainer: View {
                /// Reference to the parent view instance
                let view: \(raw: structDecl.name.text)

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
                EmbraceTraceView(\"\(raw: structDecl.name.text)\") {
                    _EmbraceBodyContainer(view: self)
                }
            }

            """
        )

        // Return the generated declarations to be injected into the user's struct
        return [
            DeclSyntax(syntax)
        ]
    }
}

/// A helper type conforming to `DiagnosticMessage` for EmbraceTraceMacro.
/// Instances carry an error message, domain, and severity for diagnostics
/// emitted during macro expansion.
///
/// This type is used internally to provide detailed error messages when the macro
/// cannot be applied correctly to a declaration.
private struct EmbraceTraceDiagnostic: DiagnosticMessage {
    /// The error message to display to the user
    let message: String

    /// A unique identifier for this type of diagnostic
    var diagnosticID: MessageID {
        MessageID(domain: "EmbraceTraceDiagnostic", id: "EmbraceTraceError")
    }

    /// The severity level of this diagnostic, always set to error
    var severity: DiagnosticSeverity { .error }
}
