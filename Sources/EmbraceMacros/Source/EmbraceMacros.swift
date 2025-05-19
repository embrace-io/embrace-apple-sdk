/// A Swift macro that automatically instruments SwiftUI views with Embrace performance traces.
///
/// The `@embraceTrace` macro intercepts a view’s `body` property at compile time
/// and wraps the generated content in an `EmbraceTraceView`, enabling detailed
/// performance monitoring without manual instrumentation calls.
///
/// # Features
/// - **Automatic Wrapping:** Injects tracing hooks around view updates and appearances.
/// - **Non-invasive:** Leaves your existing view logic and public API unchanged.
/// - **Transparent:** Generated code is private and does not pollute your module’s API.
///
/// # Usage
/// ```swift
/// @embraceTrace
/// struct ContentView: View {
///     var body: some View {
///         Text("Hello, World!")
///     }
/// }
/// ```
///
/// # Requirements
/// - Must be applied to a `struct` conforming to SwiftUI’s `View` protocol.
///
/// # Implementation Details
/// Applying this macro generates:
/// 1. A private duplicate of your `body` content.
/// 2. An internal wrapper view that hosts and traces the original content.
/// 3. A `typealias Body` rebind to the traced wrapper type.
///
/// # See Also
/// - `EmbraceTraceView`
/// - `EmbraceMacroPlugin`
///

@attached(member, names: arbitrary)
public macro embraceTrace() =
#externalMacro(
    module: "EmbraceMacroPlugin",
    type: "EmbraceTraceMacro"
)
