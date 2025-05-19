//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct EmbraceMacrosPlugin: CompilerPlugin {
    var providingMacros: [Macro.Type] = [
        EmbraceTraceMacro.self
    ]
}
