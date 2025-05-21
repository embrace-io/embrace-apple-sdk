//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
/// Represents errors that can occur during the expansion of Embrace macros.
///
/// These errors are thrown during the macro expansion phase when the macro cannot
/// be correctly applied to the target code.
enum EmbraceMacroError: Error {
    /// Thrown when the type being decorated with `@EmbraceTrace` does not conform to the `View` protocol.
    ///
    /// The `@EmbraceTrace` macro can only be applied to types that conform to SwiftUI's `View` protocol.
    case notConformingToView
    
    /// Thrown when the type being decorated with `@EmbraceTrace` is not a struct.
    ///
    /// The `@EmbraceTrace` macro can only be applied to struct types, as SwiftUI views
    /// are expected to be structs.
    case notStruct
    
    /// Thrown when the type being decorated with `@EmbraceTrace` does not have a `body` property.
    ///
    /// The `@EmbraceTrace` macro expects the decorated view to have a `body` property,
    /// which is a requirement of the `View` protocol.
    case noBody
}
