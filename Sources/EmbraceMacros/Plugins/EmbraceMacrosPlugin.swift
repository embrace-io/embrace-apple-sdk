//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if os(macOS)
import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// A Swift compiler plugin that provides macros for Embrace SDK functionality.
///
/// This plugin serves as the entry point for all Embrace-related macros,
/// registering them with the Swift compiler. Macros allow for code generation
/// and transformation at compile time.
///
@main
struct EmbraceMacrosPlugin: CompilerPlugin {

    /// The collection of macros provided by this plugin.
    ///
    /// This array lists all macro types that this plugin makes available
    /// to the Swift compiler. Each macro type represents a distinct code
    /// transformation capability.
    var providingMacros: [Macro.Type] = [
        EmbraceTraceMacro.self
    ]
}
#endif
