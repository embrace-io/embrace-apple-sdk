//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    

import Foundation
import SwiftUI

#if os(macOS)
import AppKit

protocol ViewRepresentable: NSViewRepresentable where ViewType == NSViewType {
    associatedtype ViewType: NSView
    func makeView(context: Context) -> ViewType
    func updateView(_ view: ViewType, context: Context)
}

extension ViewRepresentable {
    func makeNSView(context: Context) -> Self.NSViewType {
        makeView(context: context)
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        updateView(nsView, context: context)
    }
}
#else
import UIKit

protocol ViewRepresentable: UIViewRepresentable where ViewType == UIViewType {
    associatedtype ViewType: UIView
    func makeView(context: Context) -> ViewType
    func updateView(_ view: ViewType, context: Context)
}

extension ViewRepresentable {
    func makeUIView(context: Context) -> Self.UIViewType {
        makeView(context: context)
    }
    
    func updateUIView(_ nsView: UIViewType, context: Context) {
        updateView(nsView, context: context)
    }
}
#endif
