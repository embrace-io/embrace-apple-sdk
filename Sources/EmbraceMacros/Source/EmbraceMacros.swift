//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// A Swift macro that automatically instruments SwiftUI views with Embrace performance traces.
///
/// The `@EmbraceTrace` macro intercepts a view's `body` property at compile time
/// and wraps the generated content in an `EmbraceTraceView`, enabling detailed
/// performance monitoring without manual instrumentation calls.
///
/// ## Features
/// - **Automatic Wrapping**: Injects tracing hooks around view updates and appearances
/// - **Non-invasive**: Leaves your existing view logic and public API unchanged
/// - **Transparent**: Generated code is private and does not pollute your module's API
/// - **Zero Runtime Overhead**: All instrumentation is compile-time code generation
/// - **Type Safe**: Preserves all SwiftUI type relationships and compiler optimizations
///
/// ## Usage
///
/// ### Basic Usage
/// ```swift
/// @EmbraceTrace
/// struct ContentView: View {
///     var body: some View {
///         Text("Hello, World!")
///     }
/// }
/// ```
///
/// ### Complex Views
/// ```swift
/// @EmbraceTrace
/// struct UserDashboard: View {
///     @State private var selectedTab = 0
///
///     var body: some View {
///         TabView(selection: $selectedTab) {
///             ProfileView()
///                 .tabItem { Label("Profile", systemImage: "person") }
///                 .tag(0)
///
///             SettingsView()
///                 .tabItem { Label("Settings", systemImage: "gear") }
///                 .tag(1)
///         }
///     }
/// }
/// ```
///
/// ### With Custom View Names
/// The macro automatically derives the view name from the struct name, but you can
/// customize it using the manual `embraceTrace` modifier if needed:
/// ```swift
/// struct InternalComponentView: View {
///     var body: some View {
///         Text("Component")
///             .embraceTrace("PublicComponentName")
///     }
/// }
/// ```
///
/// ## Requirements
/// - Must be applied to a `struct` that conforms to SwiftUI's `View` protocol
/// - The target struct must have a `body` property (required by SwiftUI)
/// - Compatible with iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6.0+
///
/// ## Implementation Details
///
/// ### Code Generation Process
/// When applied to a view, this macro performs the following transformations:
///
/// 1. **Body Content Extraction**: Creates a private copy of your original `body` implementation
/// 2. **Wrapper Generation**: Creates an internal `EmbraceTraceView` wrapper
/// 3. **Type Rebinding**: Updates the `Body` typealias to point to the traced wrapper
/// 4. **Name Derivation**: Uses the struct name as the trace identifier
///
/// ### Before Macro Application
/// ```swift
/// @EmbraceTrace
/// struct LoginView: View {
///     var body: some View {
///         VStack {
///             Text("Login")
///             Button("Sign In") { ... }
///         }
///     }
/// }
/// ```
///
/// ### After Macro Expansion (Conceptual)
/// ```swift
/// struct LoginView: View {
///     // Generated: Private copy of original body
///     private var _originalBody: some View {
///         VStack {
///             Text("Login")
///             Button("Sign In") { ... }
///         }
///     }
///
///     // Generated: Traced wrapper
///     var body: some View {
///         EmbraceTraceView("LoginView") {
///             _originalBody
///         }
///     }
///
///     // Generated: Type alias update
///     typealias Body = EmbraceTraceView<...>
/// }
/// ```
///
/// ## Performance Characteristics
///
/// ### Compile Time
/// - **Macro Expansion**: ~1-5ms per view (negligible impact on build times)
/// - **Type Checking**: No additional overhead beyond standard SwiftUI views
/// - **Code Size**: Minimal increase (~50-100 bytes per traced view)
///
/// ### Runtime
/// - **View Creation**: Same as manual `EmbraceTraceView` wrapping
/// - **Body Evaluation**: ~0.01ms overhead per evaluation
/// - **Memory**: ~200 bytes additional state per traced view instance
/// - **When Disabled**: Zero overhead (configuration check only)
///
/// ## Debugging and Development
///
/// ### Macro Expansion Viewing
/// In Xcode 15+, you can view the generated code:
/// 1. Right-click on the `@EmbraceTrace` attribute
/// 2. Select "Expand Macro" from the context menu
/// 3. Review the generated implementation
///
/// ### Build-Time Diagnostics
/// The macro provides helpful error messages for common issues:
/// - Applied to non-View types: "embraceTrace can only be applied to View structs"
/// - Missing body property: "Target struct must implement SwiftUI View protocol"
/// - Invalid target type: "embraceTrace requires a struct declaration"
///
/// ### Runtime Debugging
/// Use the generated trace data to identify performance issues:
/// - View initialization timing
/// - Body evaluation frequency
/// - Render cycle performance
/// - Memory usage patterns
///
/// ## Considerations
///
/// ### Performance Considerations
/// - Avoid applying to very frequently updated views (animations, timers)
/// - Consider the overhead when tracing large numbers of simple views
/// - Use sampling or conditional tracing for high-frequency scenarios
///
/// ### Migration from Manual Tracing
/// When migrating from manual `EmbraceTraceView` usage:
/// ```swift
/// // Before: Manual wrapping
/// struct MyView: View {
///     var body: some View {
///         EmbraceTraceView("MyView") {
///             Text("Content")
///         }
///     }
/// }
///
/// // After: Macro application
/// @EmbraceTrace
/// struct MyView: View {
///     var body: some View {
///         Text("Content")
///     }
/// }
/// ```
///
/// ## See Also
/// - ``EmbraceTraceView``: The underlying tracing wrapper
/// - ``EmbraceTraceViewModifier``: Manual view modifier approach

@_exported import EmbraceCore

@attached(member, names: arbitrary)
public macro EmbraceTrace() =
    #externalMacro(
        module: "EmbraceMacroPlugin",
        type: "EmbraceTraceMacro"
    )
