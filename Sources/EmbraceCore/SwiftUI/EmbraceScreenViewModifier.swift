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
/// UIKit screens are detected automatically; SwiftUI has no reliable equivalent, so this is how you
/// say a view is a screen.
///
/// The screen is recorded when the view appears, and ends when the next screen appears — the same
/// way it works for automatically detected screens. Disappearing only records something when it
/// uncovers a screen that stayed visible underneath: dismissing a sheet returns the timeline to the
/// screen it was presented over.
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
/// - Note: This is the only way a SwiftUI screen is recorded. Hosting controllers, and view
///   controllers inside them, are not recorded as screens by default.
///
/// - Parameters:
///   - name: The screen's name. Surrounding whitespace is trimmed and long names are truncated; a
///     name that is blank once trimmed is ignored.
///   - attributes: Optional metadata recorded on this screen's transitions. The same count and
///     length limits apply as to attributes anywhere else in the SDK — past the count limit, the
///     ones kept are chosen in sorted key order, and long string values are truncated. Keys in the
///     reserved `emb.state.*` namespace are ignored.
///
///     Recorded each time the timeline moves to this screen, not each time the view re-renders.
///     Re-declaring the same screen with changed values records nothing new on its own; the latest
///     values are what a later return to this screen carries (after backgrounding, or when a sheet
///     over it is dismissed). Avoid values that track live data and expect them to update.
/// - Returns: The view, marked as a screen.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension View {
    public func embraceScreen(_ name: String, attributes: EmbraceAttributes? = nil) -> some View {
        modifier(EmbraceScreenModifier(name: name, attributes: attributes ?? [:]))
    }
}

/// Identity for one declared screen's view lifetime.
///
/// Empty on purpose. The pipeline keys screens by object identity, which a `View` cannot supply —
/// it is a struct, re-created on every evaluation. Held in `@State`, this borrows SwiftUI's own
/// notion of view identity instead.
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
                // Keeps the visible set accurate: this is what lets a dismissed sheet hand the
                // timeline back, and a screen that never reports going away stays counted
                // forever, silently stopping later screens' load times from being backdated.
                ManualScreenRegistry.reporter?.onManualScreenDisappear(
                    id: ObjectIdentifier(token),
                    name: name,
                    at: Date()
                )
            }
    }
}
