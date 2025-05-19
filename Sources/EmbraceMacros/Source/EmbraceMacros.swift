
/// A macro that automatically instruments SwiftUI views with performance tracing.
///
/// Use the `@embraceTrace` attribute on your SwiftUI View to automatically
/// instrument them with Embrace's performance monitoring. This macro intercepts the view's
/// `body` property and wraps the content with `EmbraceTraceView`, enabling
/// detailed performance tracking without manual instrumentation.
///
/// Example:
/// ```
/// @embraceTrace
/// struct ContentView: View {
///     var body: some View {
///         Text("Hello, World!")
///     }
/// }
/// ```
///
/// Requirements:
/// - Must be applied to a `struct` that conforms to SwiftUI's `View` protocol
/// - The struct must have a `body` property
///
/// - Note: This macro generates additional properties and types to facilitate tracing
///         without modifying your original view implementation.
@attached(member, names: arbitrary)
public macro embraceTrace() =
#externalMacro(
    module: "EmbraceMacroPlugin",
    type: "EmbraceTraceMacro"
)
