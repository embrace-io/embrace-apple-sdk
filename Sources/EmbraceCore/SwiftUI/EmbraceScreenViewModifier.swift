//
//  EmbraceScreenViewModifier.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Marks a SwiftUI view as a screen in the user's navigation timeline.
///
/// UIKit screens are detected automatically, but SwiftUI has no reliable equivalent — a `View` is a
/// value that the framework re-creates freely, and nothing in it says "this is a screen". Applying
/// this modifier is how you say so.
///
/// The screen is recorded when the view appears. Nothing is recorded when it disappears: the next
/// screen's appearance is what ends this one, the same way it works for automatically detected
/// screens.
///
/// Declared and automatic screens share one timeline, so navigating from a UIKit screen to a SwiftUI
/// one reads as a single continuous journey.
///
/// **Usage Examples:**
/// ```swift
/// // A screen
/// ProductDetailView()
///     .embraceScreen("ProductDetail")
///
/// // With your own metadata on the transition
/// ProductDetailView()
///     .embraceScreen("ProductDetail", attributes: ["product_id": productId])
///
/// // Tabs, sheets and navigation destinations all work the same way
/// .sheet(isPresented: $showSettings) {
///     SettingsView().embraceScreen("Settings")
/// }
/// ```
///
/// **Best Practices:**
///  - Use stable names. Screens are told apart by name, so a name built from changing data produces
///    a timeline of screens that look distinct but are not.
///  - Never put PII in the name or the attributes.
///  - Mark screens, not components. A modifier on a row or a button records a "screen" the user
///    never navigated to.
///
/// - Note: Does nothing when screen tracking is disabled, when the SDK has not started, or on
///   platforms where the feature does not run. It is always safe to leave in place.
///
/// - Note: This is the only way a SwiftUI screen is named. The `UIHostingController` presenting it
///   is never recorded as a screen on its own — its class name describes the view tree rather than
///   the screen — unless it supplies one through `EmbraceViewControllerCustomization`.
///
/// - Parameters:
///   - name: The screen's name. Surrounding whitespace is trimmed and long names are truncated; a
///     name that is blank once trimmed, or one the SDK reserves for its own use, is ignored.
///   - attributes: Optional metadata recorded on this screen's transition. Values must be strings,
///     and the same count and length limits apply as to attributes anywhere else in the SDK — past
///     the count limit, the ones kept are chosen in sorted key order. Keys in the reserved
///     `emb.state.*` namespace are ignored.
///
///     Recorded once, when the screen appears. Re-declaring the same screen with changed values
///     does not record them again — that is not a navigation — so avoid values that track live data
///     and expect them to update.
/// - Returns: The view, marked as a screen.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension View {
    public func embraceScreen(_ name: String, attributes: EmbraceAttributes? = nil) -> some View {
        modifier(EmbraceScreenModifier(name: name, attributes: attributes ?? [:]))
    }
}

/// Identity for one appearance of a declared screen.
///
/// The navigation pipeline identifies screens by object identity, which a SwiftUI `View` cannot
/// supply — it is a struct, re-created on every evaluation. Holding a reference type in `@State`
/// borrows SwiftUI's own notion of view identity: one instance per view lifetime, stable across
/// re-evaluations, and a new one when SwiftUI considers the view genuinely new.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final class ScreenIdentityToken {}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
struct EmbraceScreenModifier: ViewModifier {

    let name: String
    let attributes: EmbraceAttributes

    @State private var token = ScreenIdentityToken()

    func body(content: Content) -> some View {
        content
            .onAppear {
                ManualScreenRegistry.reporter?.onManualScreenAppear(
                    id: ObjectIdentifier(token),
                    name: name,
                    attributes: attributes,
                    at: Date()
                )
            }
            .onDisappear {
                // Reported even though it records nothing, because the pipeline tracks which screens
                // are currently visible. A screen that never reports going away stays counted as
                // visible forever, which stops later screens from having their load time attributed
                // to when the user started navigating.
                ManualScreenRegistry.reporter?.onManualScreenDisappear(
                    id: ObjectIdentifier(token),
                    name: name,
                    at: Date()
                )
            }
    }
}
