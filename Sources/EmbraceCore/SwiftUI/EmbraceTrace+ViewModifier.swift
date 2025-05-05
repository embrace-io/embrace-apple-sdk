import SwiftUI

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension View {
    func embraceTrace(_ viewName: String, attributes: [String: String]? = nil) -> some View {
        EmbraceTraceView(viewName, attributes: attributes) { self }
    }
}
