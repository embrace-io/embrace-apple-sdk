//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A macro that instruments SwiftUI View bodies with trace points.
/// Applies the `embraceTrace(_:)` view modifier to generate an instrumented body.
public struct EmbraceTraceMacro {}

extension EmbraceTraceMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw EmbraceMacroError.notStruct
        }
        
        // Ensure the struct conforms to SwiftUI View
        let inheritsView = structDecl.inheritanceClause?.inheritedTypes.contains {
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
            throw EmbraceMacroError.notConformingToView
        }
        
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
            throw EmbraceMacroError.noBody
        }
        
        guard let declaration = viewBodyVariable.bindings.first?.accessorBlock?.accessors._syntaxNode else {
            throw EmbraceMacroError.noBody
        }
        
        let syntax = DeclSyntax(
                """
                
                // @EmbraceTrace
                // This is your new `body`. It's the same as you declared above.
                // The macro adds the `embraceTrace` view modifier to it
                // which will instrument this View for you.
                // Inspired by https://github.com/SwiftUIX/SwiftUIX
                
                private var _embraceOriginalBody: some View {
                    // We have not yet found a way to call into the actual original
                    // `body`, do we need to duplicate it here.
                \(raw: declaration.trimmed.formatted().description)
                }
                
                struct _EmbraceBodyContainer: View {
                    let view: \(raw: structDecl.name.text)
                    var body: some View {
                        view._embraceOriginalBody
                    }
                }
                
                typealias Body = EmbraceTraceView<_EmbraceBodyContainer>
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
        
        return [
            DeclSyntax(syntax)
        ]
    }
}
